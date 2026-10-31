import Foundation

public struct ServiceItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let url: String
    public let icon: String
    public let category: String
    public let status: String
    public let responseTimeMs: Int
    public let statusCode: Int
    public let autoDiscovered: Bool?

    public init(
        id: String,
        name: String,
        url: String,
        icon: String,
        category: String,
        status: String,
        responseTimeMs: Int,
        statusCode: Int,
        autoDiscovered: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.icon = icon
        self.category = category
        self.status = status
        self.responseTimeMs = responseTimeMs
        self.statusCode = statusCode
        self.autoDiscovered = autoDiscovered
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case icon
        case category
        case status
        case responseTimeMs = "response_time_ms"
        case statusCode = "status_code"
        case autoDiscovered = "auto_discovered"
    }

    public var isOnline: Bool {
        status.lowercased() == "online"
    }

    public var isDegraded: Bool {
        status.lowercased() == "degraded"
    }

    public var isAutoDiscovered: Bool {
        autoDiscovered == true
    }
}
