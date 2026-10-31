import Foundation

public enum MockDataProvider {
    public static let sampleHostOverview = HostOverview(
        hostname: "srv-01",
        os: "Debian GNU/Linux 12 (bookworm)",
        uptimeSeconds: 345600, // 4 days
        cpu: CPUStats(
            usagePercent: 18.5,
            cores: 4,
            model: "Intel(R) Core(TM) i5-8250U CPU @ 1.60GHz",
            temperatureCelsius: 42.5
        ),
        memory: MemoryStats(
            totalBytes: 16_777_216_000,
            usedBytes: 8_388_608_000,
            freeBytes: 8_388_608_000,
            usagePercent: 50.0
        ),
        disks: [
            DiskStats(
                mountPoint: "/",
                filesystem: "/dev/sda1",
                totalBytes: 107_374_182_400,
                usedBytes: 48_318_382_080,
                freeBytes: 59_055_800_320,
                usagePercent: 45.0
            ),
            DiskStats(
                mountPoint: "/mnt/DATA",
                filesystem: "/dev/sdb1",
                totalBytes: 2_000_398_934_016,
                usedBytes: 1_440_287_232_491,
                freeBytes: 560_111_701_525,
                usagePercent: 72.0
            )
        ],
        network: NetworkStats(
            bytesRecvRate: 1_048_576, // 1 MB/s
            bytesSentRate: 524_288   // 512 KB/s
        ),
        containersSummary: ContainersSummary(
            total: 10,
            running: 9,
            stopped: 1,
            unhealthy: 0
        )
    )

    public static let sampleContainers: [DockerContainer] = [
        DockerContainer(
            id: "c1a2b3c4d5e6",
            name: "openwebui",
            image: "ghcr.io/open-webui/open-webui:main",
            state: "running",
            status: "Up 3 days (healthy)",
            health: "healthy",
            stack: "OpenWebUI",
            createdAt: 1709280000,
            ports: ["8080:8080"],
            cpuPercent: 2.4,
            memoryUsageBytes: 268_435_456,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "d2b3c4d5e6f7",
            name: "portainer",
            image: "portainer/portainer-ce:latest",
            state: "running",
            status: "Up 12 days",
            health: "healthy",
            stack: "Management",
            createdAt: 1708500000,
            ports: ["9443:9443", "8000:8000"],
            cpuPercent: 0.8,
            memoryUsageBytes: 134_217_728,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "e3c4d5e6f7a8",
            name: "qbittorrent",
            image: "lscr.io/linuxserver/qbittorrent:latest",
            state: "running",
            status: "Up 4 days",
            health: "healthy",
            stack: "Media",
            createdAt: 1709190000,
            ports: ["8081:8080", "6881:6881"],
            cpuPercent: 5.6,
            memoryUsageBytes: 734_003_200,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "f4d5e6a7b8c9",
            name: "radarr",
            image: "lscr.io/linuxserver/radarr:latest",
            state: "running",
            status: "Up 4 days",
            health: "healthy",
            stack: "Media",
            createdAt: 1709192000,
            ports: ["7878:7878"],
            cpuPercent: 1.1,
            memoryUsageBytes: 314_572_800,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "a5e6f7a8b9c0",
            name: "sonarr",
            image: "lscr.io/linuxserver/sonarr:latest",
            state: "running",
            status: "Up 4 days",
            health: "healthy",
            stack: "Media",
            createdAt: 1709193000,
            ports: ["8989:8989"],
            cpuPercent: 1.3,
            memoryUsageBytes: 335_544_320,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "b6f7a8b9c0d1",
            name: "jellyfin",
            image: "jellyfin/jellyfin:latest",
            state: "running",
            status: "Up 4 days",
            health: "healthy",
            stack: "Media",
            createdAt: 1709195000,
            ports: ["8096:8096"],
            cpuPercent: 4.2,
            memoryUsageBytes: 891_289_600,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "c7a8b9c0d1e2",
            name: "postgres",
            image: "postgres:16-alpine",
            state: "running",
            status: "Up 14 days (healthy)",
            health: "healthy",
            stack: "Core",
            createdAt: 1708300000,
            ports: ["5432:5432"],
            cpuPercent: 0.6,
            memoryUsageBytes: 157_286_400,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "d8b9c0d1e2f3",
            name: "redis",
            image: "redis:7-alpine",
            state: "running",
            status: "Up 14 days",
            health: "healthy",
            stack: "Core",
            createdAt: 1708301000,
            ports: ["6379:6379"],
            cpuPercent: 0.2,
            memoryUsageBytes: 41_943_040,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "e9c0d1e2f3a4",
            name: "traefik",
            image: "traefik:v3.0",
            state: "running",
            status: "Up 14 days",
            health: "healthy",
            stack: "Networking",
            createdAt: 1708302000,
            ports: ["80:80", "443:443", "8082:8080"],
            cpuPercent: 0.9,
            memoryUsageBytes: 83_886_080,
            memoryLimitBytes: 16_777_216_000
        ),
        DockerContainer(
            id: "f0d1e2f3a4b5",
            name: "backup-cron",
            image: "alpine:3.19",
            state: "exited",
            status: "Exited (0) 5 hours ago",
            health: nil,
            stack: "Maintenance",
            createdAt: 1709000000,
            ports: [],
            cpuPercent: 0.0,
            memoryUsageBytes: 0,
            memoryLimitBytes: 16_777_216_000
        )
    ]

    public static let sampleServices: [ServiceItem] = [
        ServiceItem(
            id: "beszel",
            name: "Beszel",
            url: "http://srv-01:8090",
            icon: "chart.xyaxis.line",
            category: "Monitoring",
            status: "online",
            responseTimeMs: 12,
            statusCode: 200
        ),
        ServiceItem(
            id: "portainer",
            name: "Portainer",
            url: "https://srv-01:9443",
            icon: "shippingbox.fill",
            category: "Management",
            status: "online",
            responseTimeMs: 15,
            statusCode: 200
        ),
        ServiceItem(
            id: "license-manager",
            name: "License Manager",
            url: "http://srv-01:3001",
            icon: "key.fill",
            category: "Apps",
            status: "online",
            responseTimeMs: 18,
            statusCode: 200
        ),
        ServiceItem(
            id: "qbittorrent",
            name: "qBittorrent",
            url: "http://srv-01:8081",
            icon: "arrow.down.circle.fill",
            category: "Media",
            status: "online",
            responseTimeMs: 28,
            statusCode: 200
        ),
        ServiceItem(
            id: "jellyfin",
            name: "Jellyfin",
            url: "http://srv-01:8096",
            icon: "play.tv.fill",
            category: "Media",
            status: "online",
            responseTimeMs: 24,
            statusCode: 200
        ),
        ServiceItem(
            id: "radarr",
            name: "Radarr",
            url: "http://srv-01:7878",
            icon: "film.stack.fill",
            category: "Media",
            status: "online",
            responseTimeMs: 45,
            statusCode: 200
        ),
        ServiceItem(
            id: "sonarr",
            name: "Sonarr",
            url: "http://srv-01:8989",
            icon: "tv.fill",
            category: "Media",
            status: "online",
            responseTimeMs: 41,
            statusCode: 200
        ),
        ServiceItem(
            id: "adguard",
            name: "AdGuard Home",
            url: "http://srv-01:3000",
            icon: "shield.checkered",
            category: "Networking",
            status: "online",
            responseTimeMs: 8,
            statusCode: 200
        )
    ]

    public static func sampleStats(for containerId: String) -> ContainerStats {
        ContainerStats(
            id: containerId,
            name: "openwebui",
            cpuPercent: 2.4,
            memoryUsageBytes: 268_435_456,
            memoryLimitBytes: 16_777_216_000,
            memoryPercent: 1.6,
            networkRxBytes: 52_428_800,
            networkTxBytes: 18_874_368,
            blockReadBytes: 1_048_576,
            blockWriteBytes: 4_194_304
        )
    }

    public static func sampleLogs(for containerId: String) -> ContainerLogs {
        ContainerLogs(
            containerId: containerId,
            lines: [
                "2026-03-30T10:00:00Z [info] Initializing ServerDeck agent connector...",
                "2026-03-30T10:00:02Z [info] Loading environment variables from .env",
                "2026-03-30T10:00:03Z [info] Connecting to internal database (PostgreSQL 16)",
                "2026-03-30T10:00:04Z [info] Database connection established successfully",
                "2026-03-30T10:00:05Z [info] Running automated database schema migrations...",
                "2026-03-30T10:00:06Z [info] Migrations completed: 0 pending",
                "2026-03-30T10:00:07Z [info] Loading Ollama models and tokenizer pipelines...",
                "2026-03-30T10:00:10Z [info] HTTP REST API listener started on 0.0.0.0:8080",
                "2026-03-30T10:00:11Z [info] WebSocket endpoint registered at /api/v1/events",
                "2026-03-30T10:00:12Z [info] Ready for incoming client connections via Tailscale"
            ]
        )
    }

    public static let samplePruneReport = PruneReport(
        containersDeleted: 2,
        imagesDeleted: 4,
        spaceReclaimedBytes: 1_425_800_000
    )

    public static let sampleDiagnostics = DiagnosticReport(
        hostname: "srv-01",
        platform: "Debian GNU/Linux 13 (Trixie)",
        kernel: "6.12.113+deb13-amd64",
        arch: "x86_64",
        uptimeSeconds: 440_500,
        memoryTotal: 7_206_834_176,
        memoryUsed: 1_439_326_208,
        memoryFree: 5_393_973_248,
        swapTotal: 7_445_934_080,
        swapUsed: 524_288,
        storageDetails: [
            DiskDetail(mountPoint: "/", filesystem: "ext4", totalBytes: 242_566_905_856, usedBytes: 34_578_550_784, usagePercent: 14.3),
            DiskDetail(mountPoint: "/mnt/DATA", filesystem: "ext4", totalBytes: 502_921_412_608, usedBytes: 4_621_074_432, usagePercent: 1.0)
        ],
        diagnosticLogs: [
            "Kernel: Linux version 6.12.113+deb13-amd64 (Debian 6.12.113-1)",
            "Hardware: AMD Ryzen 3 PRO 2200GE w/ Radeon Vega Graphics (4 Cores)",
            "Docker Engine: 27.1.1 (API 1.46)",
            "System Bus: D-Bus systemd login1 operational",
            "Tailscale: 100.75.107.88 connected (peer srv-01)"
        ]
    )
}
