#!/usr/bin/env bash
# ==============================================================================
#  ServerDeck 1-Click Host & Container Installer (Beszel-style)
#  Installs the native Rust host bridge daemon and deploys the backend container.
#
#  Usage:
#    curl -sSL https://raw.githubusercontent.com/GhostAndry/ServerDeck/main/scripts/install.sh | sudo bash
#  Or with options:
#    curl -sSL ... | sudo SERVERDECK_TOKEN=mysecret SERVERDECK_PORT=8080 bash
# ==============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${CYAN}${BOLD}"
cat << 'EOF'
  _____                          _____             _    
 / ____|                        |  __ \           | |   
| (___   ___ _ ____   _____ _ __| |  | | ___  ___| | __
 \___ \ / _ \ '__\ \ / / _ \ '__| |  | |/ _ \/ __| |/ /
 ____) |  __/ |   \ V /  __/ |  | |__| |  __/ (__|   < 
|_____/ \___|_|    \_/ \___|_|  |_____/ \___|\___|_|\_\
EOF
echo -e "${NC}"
echo -e "${BOLD}ServerDeck Automated Host & Container Setup${NC}"
echo "=========================================================="

# 1. Check Root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This installer must be run as root (use sudo).${NC}"
    exit 1
fi

# 2. Check Architecture & OS
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" != "Linux" ]; then
    echo -e "${RED}[ERROR] ServerDeck is designed for Linux hosts. Detected: $OS${NC}"
    exit 1
fi

case "$ARCH" in
    x86_64|amd64)
        TARGET_ARCH="x86_64"
        ;;
    aarch64|arm64)
        TARGET_ARCH="aarch64"
        ;;
    *)
        echo -e "${RED}[ERROR] Unsupported CPU architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Host System:${NC} Linux ($TARGET_ARCH)"

# 3. Check Dependencies & Package Manager
MISSING_DEPS=()

if ! command -v systemctl &>/dev/null; then
    echo -e "${RED}[ERROR] systemd is required to manage the ServerDeck host bridge daemon.${NC}"
    exit 1
fi

if ! command -v curl &>/dev/null; then
    MISSING_DEPS+=("curl")
fi

if ! command -v git &>/dev/null; then
    MISSING_DEPS+=("git")
fi

if ! command -v docker &>/dev/null; then
    MISSING_DEPS+=("docker")
fi

if command -v docker &>/dev/null && ! docker compose version &>/dev/null; then
    MISSING_DEPS+=("docker-compose-plugin")
fi

# Detect package manager
PKG_MGR="unknown"
if command -v apt-get &>/dev/null; then
    PKG_MGR="apt"
elif command -v dnf &>/dev/null; then
    PKG_MGR="dnf"
elif command -v yum &>/dev/null; then
    PKG_MGR="yum"
elif command -v pacman &>/dev/null; then
    PKG_MGR="pacman"
elif command -v zypper &>/dev/null; then
    PKG_MGR="zypper"
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}[!] Rilevate dipendenze mancanti:${NC}"
    for dep in "${MISSING_DEPS[@]}"; do
        echo -e "    • ${RED}${BOLD}$dep${NC}"
    done
    echo ""
    echo -e "${BOLD}Come desideri procedere?${NC}"
    echo -e "  ${GREEN}1)${NC} Installa automaticamente con questo script [Consigliato]"
    echo -e "  ${YELLOW}2)${NC} Installa manualmente e riesegui lo script in seguito"
    echo ""

    # Read from /dev/tty if stdin is piped (e.g. curl ... | sudo bash)
    CHOICE="1"
    if [ -t 0 ]; then
        read -r -p "Seleziona un'opzione [1/2] (default 1): " USER_INPUT || USER_INPUT="1"
        CHOICE="${USER_INPUT:-1}"
    elif [ -r /dev/tty ]; then
        read -r -p "Seleziona un'opzione [1/2] (default 1): " USER_INPUT < /dev/tty || USER_INPUT="1"
        CHOICE="${USER_INPUT:-1}"
    fi

    if [ "$CHOICE" = "2" ]; then
        echo ""
        echo -e "${CYAN}==========================================================${NC}"
        echo -e "${BOLD}Istruzioni per l'installazione manuale (${PKG_MGR}):${NC}"
        echo -e "${CYAN}==========================================================${NC}"
        case "$PKG_MGR" in
            apt)
                echo "1. Installa utilità di base:"
                echo "   sudo apt-get update && sudo apt-get install -y curl git"
                echo "2. Installa Docker Engine e Docker Compose:"
                echo "   curl -fsSL https://get.docker.com | sudo sh"
                echo "   sudo systemctl enable --now docker"
                ;;
            dnf|yum)
                echo "1. Installa utilità di base:"
                echo "   sudo $PKG_MGR install -y curl git"
                echo "2. Installa Docker Engine e Docker Compose:"
                echo "   curl -fsSL https://get.docker.com | sudo sh"
                echo "   sudo systemctl enable --now docker"
                ;;
            pacman)
                echo "1. Installa utilità e Docker:"
                echo "   sudo pacman -Sy --noconfirm curl git docker docker-compose"
                echo "   sudo systemctl enable --now docker"
                ;;
            *)
                echo "Installa i pacchetti mancanti (${MISSING_DEPS[*]}) con il gestore pacchetti del tuo sistema."
                echo "Poi avvia Docker con: sudo systemctl enable --now docker"
                ;;
        esac
        echo ""
        echo -e "${YELLOW}Una volta completata l'installazione manuale, riesegui semplicemente:${NC}"
        echo "  curl -sSL https://raw.githubusercontent.com/GhostAndry/ServerDeck/main/scripts/install.sh | sudo bash"
        echo -e "${CYAN}==========================================================${NC}"
        exit 0
    else
        echo -e "${BLUE}==> Installazione automatica delle dipendenze in corso...${NC}"
        
        NEED_APT_UPDATE=1
        for dep in "${MISSING_DEPS[@]}"; do
            if [ "$dep" = "curl" ] || [ "$dep" = "git" ]; then
                case "$PKG_MGR" in
                    apt)
                        if [ "$NEED_APT_UPDATE" -eq 1 ]; then
                            apt-get update -y
                            NEED_APT_UPDATE=0
                        fi
                        apt-get install -y "$dep"
                        ;;
                    dnf|yum)
                        $PKG_MGR install -y "$dep"
                        ;;
                    pacman)
                        pacman -Sy --noconfirm "$dep"
                        ;;
                    zypper)
                        zypper install -y "$dep"
                        ;;
                esac
            fi
        done

        if [[ " ${MISSING_DEPS[*]} " =~ " docker " ]] || [[ " ${MISSING_DEPS[*]} " =~ " docker-compose-plugin " ]]; then
            echo -e "${BLUE}==> Installazione di Docker Engine & Compose tramite script ufficiale...${NC}"
            curl -fsSL https://get.docker.com | sh
            systemctl enable --now docker
        fi
        echo -e "${GREEN}✓ Tutte le dipendenze sono state installate con successo!${NC}"
    fi
fi

echo -e "${GREEN}✓ Docker Engine:${NC} $(docker --version 2>/dev/null || echo 'OK')"
echo -e "${GREEN}✓ Docker Compose:${NC} $(docker compose version --short 2>/dev/null || echo 'OK')"

# 4. Directory & Configuration Setup
if [ -d "/mnt/DATA" ]; then
    DEFAULT_DIR="/mnt/DATA/serverdeck"
else
    DEFAULT_DIR="/opt/serverdeck"
fi
INSTALL_DIR="${SERVERDECK_DIR:-$DEFAULT_DIR}"
PORT="${SERVERDECK_PORT:-8080}"

mkdir -p "$INSTALL_DIR"/{config,data,bridge,backend,scripts}
cd "$INSTALL_DIR"

# Token generation if not provided
if [ -z "${SERVERDECK_TOKEN:-}" ]; then
    if [ -f "$INSTALL_DIR/.env" ] && grep -q "SERVERDECK_TOKEN=" "$INSTALL_DIR/.env"; then
        TOKEN=$(grep "SERVERDECK_TOKEN=" "$INSTALL_DIR/.env" | cut -d '=' -f2 | tr -d ' "')
    else
        TOKEN=$(head -c 16 /dev/urandom | xxd -p 2>/dev/null || openssl rand -hex 16 2>/dev/null || echo "serverdeck-$(date +%s)")
    fi
else
    TOKEN="$SERVERDECK_TOKEN"
fi

cat << EOF > "$INSTALL_DIR/.env"
SERVERDECK_TOKEN=$TOKEN
SERVERDECK_LISTEN=0.0.0.0:$PORT
EOF

# 5. Fetch / Sync ServerDeck Sources if needed
REPO_URL="https://github.com/GhostAndry/ServerDeck.git"

if [ ! -f "$INSTALL_DIR/backend/Dockerfile" ]; then
    echo -e "${BLUE}==> Downloading ServerDeck codebase from GitHub...${NC}"
    TMP_CLONE="/tmp/serverdeck-install-$$"
    rm -rf "$TMP_CLONE"
    git clone --depth 1 "$REPO_URL" "$TMP_CLONE"
    cp -r "$TMP_CLONE"/backend/* "$INSTALL_DIR/backend/"
    cp -r "$TMP_CLONE"/bridge/* "$INSTALL_DIR/bridge/"
    cp -r "$TMP_CLONE"/scripts/* "$INSTALL_DIR/scripts/"
    if [ ! -f "$INSTALL_DIR/config/services.yml" ]; then
        cp "$TMP_CLONE/backend/config/services.yml" "$INSTALL_DIR/config/services.yml"
    fi
    rm -rf "$TMP_CLONE"
fi

# 6. Build & Install Native Host Bridge (Rust)
echo -e "${BLUE}==> Building native Rust host bridge agent...${NC}"
BRIDGE_BIN="$INSTALL_DIR/bridge/target/release/serverdeck-bridge"

if [ ! -f "$BRIDGE_BIN" ]; then
    # Compile static binary inside official rust container with zero host dependencies
    docker run --rm -v "$INSTALL_DIR/bridge:/src" -w /src rust:alpine cargo build --release
fi

echo -e "${BLUE}==> Installing host bridge daemon into systemd...${NC}"
install -m 755 "$BRIDGE_BIN" /usr/local/bin/serverdeck-bridge

cat << 'EOF' > /etc/systemd/system/serverdeck-bridge.service
[Unit]
Description=ServerDeck Native Host Bridge Daemon
Documentation=https://github.com/GhostAndry/ServerDeck
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/serverdeck-bridge --socket /run/serverdeck/bridge.sock
Restart=always
RestartSec=3
RuntimeDirectory=serverdeck
RuntimeDirectoryMode=0755
KillMode=process
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now serverdeck-bridge.service

# Wait up to 5s for socket
for i in {1..10}; do
    if [ -S "/run/serverdeck/bridge.sock" ]; then
        break
    fi
    sleep 0.5
done

if [ ! -S "/run/serverdeck/bridge.sock" ]; then
    echo -e "${RED}[ERROR] Bridge socket was not created at /run/serverdeck/bridge.sock.${NC}"
    systemctl status serverdeck-bridge.service --no-pager
    exit 1
fi
echo -e "${GREEN}✓ Native Host Bridge:${NC} Active on /run/serverdeck/bridge.sock"

# 7. Write Compose File and Start Backend Container (Unprivileged)
HOSTNAME_STR="$(cat /etc/hostname 2>/dev/null || uname -n)"

cat << EOF > "$INSTALL_DIR/compose.yml"
services:
  serverdeck-backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: serverdeck-backend
    hostname: $HOSTNAME_STR
    restart: unless-stopped
    init: true

    environment:
      TZ: Europe/Rome
      SERVERDECK_LISTEN: "0.0.0.0:$PORT"
      SERVERDECK_CONFIG: /app/config/services.yml
      SERVERDECK_DB: /app/data/serverdeck.db
      SERVERDECK_TOKEN: \${SERVERDECK_TOKEN}
      SERVERDECK_BRIDGE_SOCKET: /var/run/serverdeck/bridge.sock
      HOST_PROC: /proc
      HOST_SYS: /sys
      HOST_ROOT: /
      SERVERDECK_HOSTNAME: $HOSTNAME_STR

    ports:
      - "$PORT:$PORT"

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /run/serverdeck/bridge.sock:/var/run/serverdeck/bridge.sock
      - /proc:/proc:ro
      - /sys:/sys:ro
      - /:/host/root:ro
      - $INSTALL_DIR/config:/app/config
      - $INSTALL_DIR/data:/app/data

    security_opt:
      - no-new-privileges:true
EOF

echo -e "${BLUE}==> Deploying unprivileged backend container...${NC}"
docker compose -f "$INSTALL_DIR/compose.yml" up -d --build

# 8. Detect Network IPs
LAN_IP="$(ip -4 route get 1.1.1.1 2>/dev/null | grep -oP 'src \K\S+' || hostname -I 2>/dev/null | awk '{print $1}')"
TAILSCALE_IP="$(tailscale ip -4 2>/dev/null || ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "")"

echo ""
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo -e "${GREEN}${BOLD}     ✓ ServerDeck Successfully Installed & Running!      ${NC}"
echo -e "${GREEN}${BOLD}==========================================================${NC}"
echo ""
echo -e "  ${BOLD}Hostname:${NC}        $HOSTNAME_STR"
echo -e "  ${BOLD}Local LAN URL:${NC}   http://${LAN_IP}:${PORT}"
if [ -n "$TAILSCALE_IP" ]; then
    echo -e "  ${BOLD}Tailscale URL:${NC}   http://${TAILSCALE_IP}:${PORT}"
fi
echo -e "  ${BOLD}API Token:${NC}       ${CYAN}${BOLD}${TOKEN}${NC}"
echo ""
echo -e "${YELLOW}${BOLD}In the ServerDeck iOS App:${NC}"
echo "  1. Open ServerDeck on your iPhone."
echo "  2. Go to Settings -> 'Add Server'."
echo "  3. Enter the Name, LAN URL, Tailscale URL, and Token shown above."
echo "  4. Tap 'Test Connection' and Save!"
echo "=========================================================="
