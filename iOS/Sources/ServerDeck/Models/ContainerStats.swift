import Foundation

public struct ContainerStats: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let cpuPercent: Double
    public let memoryUsageBytes: Int64
    public let memoryLimitBytes: Int64
    public let memoryPercent: Double
    public let networkRxBytes: Int64
    public let networkTxBytes: Int64
    public let blockReadBytes: Int64
    public let blockWriteBytes: Int64

    public init(
        id: String,
        name: String,
        cpuPercent: Double,
        memoryUsageBytes: Int64,
        memoryLimitBytes: Int64,
        memoryPercent: Double,
        networkRxBytes: Int64,
        networkTxBytes: Int64,
        blockReadBytes: Int64,
        blockWriteBytes: Int64
    ) {
        self.id = id
        self.name = name
        self.cpuPercent = cpuPercent
        self.memoryUsageBytes = memoryUsageBytes
        self.memoryLimitBytes = memoryLimitBytes
        self.memoryPercent = memoryPercent
        self.networkRxBytes = networkRxBytes
        self.networkTxBytes = networkTxBytes
        self.blockReadBytes = blockReadBytes
        self.blockWriteBytes = blockWriteBytes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case cpuPercent = "cpu_percent"
        case memoryUsageBytes = "memory_usage_bytes"
        case memoryLimitBytes = "memory_limit_bytes"
        case memoryPercent = "memory_percent"
        case networkRxBytes = "network_rx_bytes"
        case networkTxBytes = "network_tx_bytes"
        case blockReadBytes = "block_read_bytes"
        case blockWriteBytes = "block_write_bytes"
    }
}
