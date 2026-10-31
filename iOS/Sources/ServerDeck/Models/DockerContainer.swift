import Foundation

public struct DockerContainer: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let image: String
    public let state: String
    public let status: String
    public let health: String?
    public let stack: String?
    public let createdAt: Int64
    public let ports: [String]
    public let cpuPercent: Double
    public let memoryUsageBytes: Int64
    public let memoryLimitBytes: Int64

    public init(
        id: String,
        name: String,
        image: String,
        state: String,
        status: String,
        health: String? = nil,
        stack: String? = nil,
        createdAt: Int64 = 0,
        ports: [String] = [],
        cpuPercent: Double = 0.0,
        memoryUsageBytes: Int64 = 0,
        memoryLimitBytes: Int64 = 0
    ) {
        self.id = id
        self.name = name
        self.image = image
        self.state = state
        self.status = status
        self.health = health
        self.stack = stack
        self.createdAt = createdAt
        self.ports = ports
        self.cpuPercent = cpuPercent
        self.memoryUsageBytes = memoryUsageBytes
        self.memoryLimitBytes = memoryLimitBytes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case image
        case state
        case status
        case health
        case stack
        case createdAt = "created_at"
        case ports
        case cpuPercent = "cpu_percent"
        case memoryUsageBytes = "memory_usage_bytes"
        case memoryLimitBytes = "memory_limit_bytes"
    }

    public var cleanName: String {
        name.hasPrefix("/") ? String(name.dropFirst()) : name
    }

    public var isRunning: Bool {
        state.lowercased() == "running"
    }

    public var isUnhealthy: Bool {
        health?.lowercased() == "unhealthy"
    }

    public var memoryPercent: Double {
        guard memoryLimitBytes > 0 else { return 0.0 }
        return (Double(memoryUsageBytes) / Double(memoryLimitBytes)) * 100.0
    }
}
