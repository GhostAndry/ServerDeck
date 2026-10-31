import Foundation

public struct DiskStats: Codable, Sendable, Identifiable, Hashable {
    public var id: String { mountPoint }
    public let mountPoint: String
    public let filesystem: String
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let freeBytes: Int64
    public let usagePercent: Double

    public init(
        mountPoint: String,
        filesystem: String,
        totalBytes: Int64,
        usedBytes: Int64,
        freeBytes: Int64,
        usagePercent: Double
    ) {
        self.mountPoint = mountPoint
        self.filesystem = filesystem
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.usagePercent = usagePercent
    }

    enum CodingKeys: String, CodingKey {
        case mountPoint = "mount_point"
        case filesystem
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case freeBytes = "free_bytes"
        case usagePercent = "usage_percent"
    }

    /// True if usage is above 80% (warning threshold as specified in app.md)
    public var isWarning: Bool {
        usagePercent >= 80.0
    }

    /// True if usage is above 90% (critical threshold)
    public var isCritical: Bool {
        usagePercent >= 90.0
    }
}
