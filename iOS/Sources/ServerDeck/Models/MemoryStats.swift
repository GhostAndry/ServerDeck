import Foundation

public struct MemoryStats: Codable, Sendable, Hashable {
    public let totalBytes: Int64
    public let usedBytes: Int64
    public let freeBytes: Int64
    public let usagePercent: Double

    public init(
        totalBytes: Int64,
        usedBytes: Int64,
        freeBytes: Int64,
        usagePercent: Double
    ) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.usagePercent = usagePercent
    }

    enum CodingKeys: String, CodingKey {
        case totalBytes = "total_bytes"
        case usedBytes = "used_bytes"
        case freeBytes = "free_bytes"
        case usagePercent = "usage_percent"
    }
}
