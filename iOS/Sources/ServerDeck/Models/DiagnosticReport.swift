import Foundation

public struct DiskDetail: Codable, Sendable, Identifiable, Hashable {
    public var id: String { mountPoint }
    public let mountPoint: String
    public let filesystem: String
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let usagePercent: Double

    enum CodingKeys: String, CodingKey {
        case mountPoint = "mount_point"
        case filesystem
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case usagePercent = "usage_percent"
    }

    public init(
        mountPoint: String,
        filesystem: String,
        totalBytes: Int64,
        usedBytes: Int64,
        usagePercent: Double
    ) {
        self.mountPoint = mountPoint
        self.filesystem = filesystem
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.usagePercent = usagePercent
    }
}

public struct DiagnosticReport: Codable, Sendable {
    public let hostname: String
    public let platform: String
    public let kernel: String
    public let arch: String
    public let uptimeSeconds: Int64
    public let memoryTotal: Int64
    public let memoryUsed: Int64
    public let memoryFree: Int64
    public let swapTotal: Int64
    public let swapUsed: Int64
    public let storageDetails: [DiskDetail]?
    public let diagnosticLogs: [String]?

    enum CodingKeys: String, CodingKey {
        case hostname
        case platform
        case kernel
        case arch
        case uptimeSeconds = "uptime_seconds"
        case memoryTotal = "memory_total_bytes"
        case memoryUsed = "memory_used_bytes"
        case memoryFree = "memory_free_bytes"
        case swapTotal = "swap_total_bytes"
        case swapUsed = "swap_used_bytes"
        case storageDetails = "storage_details"
        case diagnosticLogs = "diagnostic_logs"
    }

    public init(
        hostname: String,
        platform: String,
        kernel: String,
        arch: String,
        uptimeSeconds: Int64,
        memoryTotal: Int64,
        memoryUsed: Int64,
        memoryFree: Int64,
        swapTotal: Int64,
        swapUsed: Int64,
        storageDetails: [DiskDetail]? = nil,
        diagnosticLogs: [String]? = nil
    ) {
        self.hostname = hostname
        self.platform = platform
        self.kernel = kernel
        self.arch = arch
        self.uptimeSeconds = uptimeSeconds
        self.memoryTotal = memoryTotal
        self.memoryUsed = memoryUsed
        self.memoryFree = memoryFree
        self.swapTotal = swapTotal
        self.swapUsed = swapUsed
        self.storageDetails = storageDetails
        self.diagnosticLogs = diagnosticLogs
    }
}
