import SwiftUI
import Combine

@MainActor
public final class OverviewViewModel: ObservableObject {
    @Published public private(set) var hostOverview: HostOverview?
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public var errorMessage: String?

    private let apiClient: APIClient
    private let webSocketManager: WebSocketManager
    private var cancellables = Set<AnyCancellable>()

    public init(apiClient: APIClient, webSocketManager: WebSocketManager) {
        self.apiClient = apiClient
        self.webSocketManager = webSocketManager

        // Listen for live updates via WebSocket
        webSocketManager.$latestHostOverview
            .compactMap { $0 }
            .sink { [weak self] liveOverview in
                self?.hostOverview = liveOverview
            }
            .store(in: &cancellables)

        // When WebSocket disconnects or reconnects, notify view so counters drop to 0
        webSocketManager.$state
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    public func loadOverview(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator && hostOverview == nil {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        do {
            let overview = try await apiClient.fetchHostOverview()
            self.hostOverview = overview
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    // MARK: - Connection State
    public var isConnected: Bool {
        webSocketManager.state.isConnected
    }

    // MARK: - Computed Properties (Zeroed out when disconnected)

    public var hostname: String {
        hostOverview?.hostname ?? (isConnected ? "srv-01" : "Disconnected")
    }

    public var osDescription: String {
        hostOverview?.os ?? (isConnected ? "Linux" : "Server non raggiungibile")
    }

    public var formattedUptime: String {
        guard isConnected, let seconds = hostOverview?.uptimeSeconds, seconds > 0 else { return "--" }
        return Formatters.formatUptime(seconds)
    }

    public var cpuUsagePercent: Double {
        guard isConnected else { return 0.0 }
        return hostOverview?.cpu.usagePercent ?? 0.0
    }

    public var cpuModel: String {
        hostOverview?.cpu.model ?? "Multi-Core Processor"
    }

    public var cpuCores: Int {
        hostOverview?.cpu.cores ?? 1
    }

    public var cpuTemperature: String {
        guard isConnected, let temp = hostOverview?.cpu.temperatureCelsius else { return "--" }
        return String(format: "%.1f°C", temp)
    }

    public var memoryUsagePercent: Double {
        guard isConnected else { return 0.0 }
        return hostOverview?.memory.usagePercent ?? 0.0
    }

    public var formattedMemoryUsed: String {
        guard isConnected, let bytes = hostOverview?.memory.usedBytes else { return "0 B" }
        return Formatters.formatBytes(bytes)
    }

    public var formattedMemoryTotal: String {
        guard let bytes = hostOverview?.memory.totalBytes else { return "--" }
        return Formatters.formatBytes(bytes)
    }

    public var disks: [DiskStats] {
        hostOverview?.disks ?? []
    }

    public var rootDisk: DiskStats? {
        disks.first(where: { $0.mountPoint == "/" })
    }

    public var dataDisk: DiskStats? {
        disks.first(where: { $0.mountPoint == "/mnt/DATA" })
    }

    public var otherDisks: [DiskStats] {
        disks.filter { $0.mountPoint != "/" && $0.mountPoint != "/mnt/DATA" }
    }

    public var networkRxRate: String {
        guard isConnected, let rate = hostOverview?.network.bytesRecvRate else { return "0 B/s" }
        return Formatters.formatRate(rate)
    }

    public var networkTxRate: String {
        guard isConnected, let rate = hostOverview?.network.bytesSentRate else { return "0 B/s" }
        return Formatters.formatRate(rate)
    }

    public var containersSummary: ContainersSummary {
        guard isConnected else {
            // When disconnected, zero running counters so UI immediately reflects disconnection
            return ContainersSummary(
                total: hostOverview?.containersSummary.total ?? 0,
                running: 0,
                stopped: hostOverview?.containersSummary.total ?? 0,
                unhealthy: 0
            )
        }
        return hostOverview?.containersSummary ?? ContainersSummary(total: 0, running: 0, stopped: 0, unhealthy: 0)
    }
}
