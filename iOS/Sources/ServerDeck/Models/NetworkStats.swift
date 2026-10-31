import Foundation

public struct NetworkStats: Codable, Sendable, Hashable {
    public let bytesRecvRate: Double
    public let bytesSentRate: Double

    public init(bytesRecvRate: Double, bytesSentRate: Double) {
        self.bytesRecvRate = bytesRecvRate
        self.bytesSentRate = bytesSentRate
    }

    enum CodingKeys: String, CodingKey {
        case bytesRecvRate = "bytes_recv_rate"
        case bytesSentRate = "bytes_sent_rate"
    }
}
