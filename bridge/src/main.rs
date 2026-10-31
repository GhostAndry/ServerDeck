use serde::{Deserialize, Serialize};
use std::env;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::{Path, PathBuf};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

const DEFAULT_SOCKET_PATH: &str = "/run/serverdeck/bridge.sock";
const VERSION: &str = "1.0.0";

#[derive(Debug, Deserialize)]
#[serde(tag = "action", rename_all = "snake_case")]
enum Request {
    Ping,
    Exec {
        command: String,
    },
    Reboot {
        #[serde(default = "default_delay")]
        delay_secs: u64,
    },
    Shutdown {
        #[serde(default = "default_delay")]
        delay_secs: u64,
    },
    Diagnostics,
}

fn default_delay() -> u64 {
    3
}

#[derive(Debug, Serialize)]
#[serde(untagged)]
enum Response {
    Ping {
        status: String,
        version: String,
        hostname: String,
    },
    Exec {
        success: bool,
        command: String,
        stdout: String,
        stderr: String,
        exit_code: i32,
        duration_ms: u128,
    },
    Action {
        success: bool,
        action: String,
        message: String,
    },
    Diagnostics {
        hostname: String,
        platform: String,
        kernel: String,
        uptime_seconds: u64,
        load_average: String,
        memory_total_bytes: u64,
        memory_free_bytes: u64,
        swap_total_bytes: u64,
        swap_free_bytes: u64,
    },
    Error {
        success: bool,
        error: String,
    },
}

fn main() {
    println!("[ServerDeck Bridge v{}] Starting native host agent...", VERSION);

    let mut socket_path = PathBuf::from(DEFAULT_SOCKET_PATH);
    let mut args = env::args().skip(1);
    while let Some(arg) = args.next() {
        if arg == "--socket" || arg == "-s" {
            if let Some(val) = args.next() {
                socket_path = PathBuf::from(val);
            }
        }
    }

    // Ensure parent directory exists (e.g. /run/serverdeck)
    if let Some(parent) = socket_path.parent() {
        if !parent.exists() {
            if let Err(e) = fs::create_dir_all(parent) {
                eprintln!("[ServerDeck Bridge] Error creating directory {:?}: {}", parent, e);
            }
        }
    }

    // Clean up stale socket file if present
    if socket_path.exists() {
        let _ = fs::remove_file(&socket_path);
    }

    let listener = match UnixListener::bind(&socket_path) {
        Ok(l) => l,
        Err(e) => {
            eprintln!("[ServerDeck Bridge] Failed to bind Unix socket at {:?}: {}", socket_path, e);
            std::process::exit(1);
        }
    };

    // Set socket permissions to 0666 so container / non-root processes can talk to it
    if let Err(e) = fs::set_permissions(&socket_path, fs::Permissions::from_mode(0o666)) {
        eprintln!("[ServerDeck Bridge] Warning: Failed to set socket permissions: {}", e);
    }

    println!("[ServerDeck Bridge] Listening on UNIX domain socket at {:?}", socket_path);

    // Setup cleanup on exit
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();
    let sock_path_cleanup = socket_path.clone();

    // Spawn client handling loop
    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                thread::spawn(move || {
                    handle_client(stream);
                });
            }
            Err(e) => {
                if !r.load(Ordering::SeqCst) {
                    break;
                }
                eprintln!("[ServerDeck Bridge] Connection accept error: {}", e);
            }
        }
    }

    let _ = fs::remove_file(sock_path_cleanup);
}

fn handle_client(mut stream: UnixStream) {
    let mut reader = BufReader::new(stream.try_clone().expect("clone stream"));
    let mut line = String::new();

    while let Ok(bytes_read) = reader.read_line(&mut line) {
        if bytes_read == 0 {
            break; // Connection closed
        }

        let trimmed = line.trim();
        if trimmed.is_empty() {
            line.clear();
            continue;
        }

        let resp = match serde_json::from_str::<Request>(trimmed) {
            Ok(req) => handle_request(req),
            Err(e) => Response::Error {
                success: false,
                error: format!("Invalid request payload: {}", e),
            },
        };

        if let Ok(mut json_bytes) = serde_json::to_vec(&resp) {
            json_bytes.push(b'\n');
            let _ = stream.write_all(&json_bytes);
            let _ = stream.flush();
        }

        line.clear();
    }
}

fn handle_request(req: Request) -> Response {
    match req {
        Request::Ping => {
            let hostname = get_hostname();
            Response::Ping {
                status: "pong".to_string(),
                version: VERSION.to_string(),
                hostname,
            }
        }
        Request::Exec { command } => {
            let start = Instant::now();
            println!("[ServerDeck Bridge] Executing host command: {}", command);

            let output = Command::new("sh")
                .arg("-c")
                .arg(&command)
                .output();

            let duration_ms = start.elapsed().as_millis();

            match output {
                Ok(out) => {
                    let stdout = String::from_utf8_lossy(&out.stdout).to_string();
                    let stderr = String::from_utf8_lossy(&out.stderr).to_string();
                    let exit_code = out.status.code().unwrap_or(1);
                    Response::Exec {
                        success: out.status.success(),
                        command,
                        stdout,
                        stderr,
                        exit_code,
                        duration_ms,
                    }
                }
                Err(e) => Response::Exec {
                    success: false,
                    command,
                    stdout: String::new(),
                    stderr: format!("Failed to execute process: {}", e),
                    exit_code: 1,
                    duration_ms,
                },
            }
        }
        Request::Reboot { delay_secs } => {
            println!("[ServerDeck Bridge] Scheduling host reboot in {}s...", delay_secs);
            thread::spawn(move || {
                thread::sleep(Duration::from_secs(delay_secs));
                println!("[ServerDeck Bridge] Executing systemctl reboot now!");
                let _ = Command::new("systemctl").arg("reboot").status();
            });

            Response::Action {
                success: true,
                action: "reboot".to_string(),
                message: format!("Host reboot scheduled in {} seconds", delay_secs),
            }
        }
        Request::Shutdown { delay_secs } => {
            println!("[ServerDeck Bridge] Scheduling host shutdown in {}s...", delay_secs);
            thread::spawn(move || {
                thread::sleep(Duration::from_secs(delay_secs));
                println!("[ServerDeck Bridge] Executing systemctl poweroff now!");
                let _ = Command::new("systemctl").arg("poweroff").status();
            });

            Response::Action {
                success: true,
                action: "shutdown".to_string(),
                message: format!("Host power-off scheduled in {} seconds", delay_secs),
            }
        }
        Request::Diagnostics => {
            let hostname = get_hostname();
            let platform = get_platform_name();
            let kernel = get_kernel_version();
            let (uptime, load_avg) = get_uptime_and_load();
            let (mem_total, mem_free, swap_total, swap_free) = get_memory_info();

            Response::Diagnostics {
                hostname,
                platform,
                kernel,
                uptime_seconds: uptime,
                load_average: load_avg,
                memory_total_bytes: mem_total,
                memory_free_bytes: mem_free,
                swap_total_bytes: swap_total,
                swap_free_bytes: swap_free,
            }
        }
    }
}

// Helpers for native Linux telemetry without heavy external dependencies
fn get_hostname() -> String {
    if let Ok(content) = fs::read_to_string("/etc/hostname") {
        let t = content.trim();
        if !t.is_empty() {
            return t.to_string();
        }
    }
    env::var("HOSTNAME").unwrap_or_else(|_| "srv-01".to_string())
}

fn get_platform_name() -> String {
    if let Ok(content) = fs::read_to_string("/etc/os-release") {
        for line in content.lines() {
            if line.starts_with("PRETTY_NAME=") {
                let val = line.trim_start_matches("PRETTY_NAME=").trim_matches('"');
                if !val.is_empty() {
                    return val.to_string();
                }
            }
        }
    }
    "Debian GNU/Linux 13 (trixie)".to_string()
}

fn get_kernel_version() -> String {
    if let Ok(content) = fs::read_to_string("/proc/version") {
        let words: Vec<&str> = content.split_whitespace().collect();
        if words.len() >= 3 {
            return words[2].to_string();
        }
    }
    "Linux".to_string()
}

fn get_uptime_and_load() -> (u64, String) {
    let mut uptime = 0;
    if let Ok(content) = fs::read_to_string("/proc/uptime") {
        if let Some(first) = content.split_whitespace().next() {
            if let Ok(val) = first.parse::<f64>() {
                uptime = val as u64;
            }
        }
    }

    let load_avg = fs::read_to_string("/proc/loadavg")
        .unwrap_or_else(|_| "0.00 0.00 0.00".to_string())
        .trim()
        .to_string();

    (uptime, load_avg)
}

fn get_memory_info() -> (u64, u64, u64, u64) {
    let mut mem_total = 0;
    let mut mem_free = 0;
    let mut swap_total = 0;
    let mut swap_free = 0;

    if let Ok(content) = fs::read_to_string("/proc/meminfo") {
        for line in content.lines() {
            let parts: Vec<&str> = line.split_whitespace().collect();
            if parts.len() >= 2 {
                let kb: u64 = parts[1].parse().unwrap_or(0);
                let bytes = kb * 1024;
                match parts[0] {
                    "MemTotal:" => mem_total = bytes,
                    "MemAvailable:" | "MemFree:" if mem_free == 0 => mem_free = bytes,
                    "SwapTotal:" => swap_total = bytes,
                    "SwapFree:" => swap_free = bytes,
                    _ => {}
                }
            }
        }
    }

    (mem_total, mem_free, swap_total, swap_free)
}
