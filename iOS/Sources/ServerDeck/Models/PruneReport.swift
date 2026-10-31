import Foundation

public struct PruneReport: Codable, Sendable {
    public let containersDeleted: Int
    public let imagesDeleted: Int
    public let spaceReclaimedBytes: Int64

    enum CodingKeys: String, CodingKey {
        case containersDeleted = "containers_deleted"
        case imagesDeleted = "images_deleted"
        case spaceReclaimedBytes = "space_reclaimed_bytes"
    }

    public init(
        containersDeleted: Int,
        imagesDeleted: Int,
        spaceReclaimedBytes: Int64
    ) {
        self.containersDeleted = containersDeleted
        self.imagesDeleted = imagesDeleted
        self.spaceReclaimedBytes = spaceReclaimedBytes
    }

    public var formattedReclaimed: String {
        Formatters.formatBytes(spaceReclaimedBytes)
    }
}

public struct RestartUnhealthyResponse: Codable, Sendable {
    public let success: Bool
    public let restartedCount: Int
    public let containers: [String]?
    public let message: String?

    enum CodingKeys: String, CodingKey {
        case success
        case restartedCount = "restarted_count"
        case containers
        case message
    }

    public init(
        success: Bool,
        restartedCount: Int,
        containers: [String]? = nil,
        message: String? = nil
    ) {
        self.success = success
        self.restartedCount = restartedCount
        self.containers = containers
        self.message = message
    }
}
