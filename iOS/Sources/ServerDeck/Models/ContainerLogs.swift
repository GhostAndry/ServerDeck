import Foundation

public struct ContainerLogs: Codable, Sendable, Hashable {
    public let containerId: String
    public let lines: [String]

    public init(containerId: String, lines: [String]) {
        self.containerId = containerId
        self.lines = lines
    }

    enum CodingKeys: String, CodingKey {
        case containerId = "container_id"
        case lines
    }
}
