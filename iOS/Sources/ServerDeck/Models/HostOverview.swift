import Foundation

public struct HostOverview: Codable, Sendable, Identifiable, Hashable {
    public var id: String { hostname }
    public let hostname: String
    public let os: String
    public let uptimeSeconds: Int64
    public let cpu: CPUStats
    public let memory: MemoryStats
    public let disks: [DiskStats]
    public let network: NetworkStats
    public let containersSummary: ContainersSummary

    public init(
        hostname: String,
        os: String,
        uptimeSeconds: Int64,
        cpu: CPUStats,
        memory: MemoryStats,
        disks: [DiskStats],
        network: NetworkStats,
        containersSummary: ContainersSummary
    ) {
        self.hostname = hostname
        self.os = os
        self.uptimeSeconds = uptimeSeconds
        self.cpu = cpu
        self.memory = memory
        self.disks = disks
        self.network = network
        self.containersSummary = containersSummary
    }

    enum CodingKeys: String, CodingKey {
        case hostname
        case os
        case uptimeSeconds = "uptime_seconds"
        case cpu
        case memory
        case disks
        case network
        case containersSummary = "containers_summary"
    }
}
