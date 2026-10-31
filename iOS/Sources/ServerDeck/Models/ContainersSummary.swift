import Foundation

public struct ContainersSummary: Codable, Sendable, Hashable {
    public let total: Int
    public let running: Int
    public let stopped: Int
    public let unhealthy: Int

    public init(total: Int, running: Int, stopped: Int, unhealthy: Int) {
        self.total = total
        self.running = running
        self.stopped = stopped
        self.unhealthy = unhealthy
    }
}
