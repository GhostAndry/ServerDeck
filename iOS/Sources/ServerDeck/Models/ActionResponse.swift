import Foundation

public struct ActionResponse: Codable, Sendable, Hashable {
    public let success: Bool
    public let message: String

    public init(success: Bool, message: String) {
        self.success = success
        self.message = message
    }
}
