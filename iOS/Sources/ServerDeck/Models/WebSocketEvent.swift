import Foundation

public struct ContainerEventData: Codable, Sendable, Hashable {
    public let containerId: String
    public let action: String
    public let status: String

    public init(containerId: String, action: String, status: String) {
        self.containerId = containerId
        self.action = action
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case containerId = "container_id"
        case action
        case status
    }
}

public enum WebSocketEventPayload: Sendable {
    case hostTick(HostOverview)
    case containerEvent(ContainerEventData)
    case raw(Data)
}

public struct WebSocketEvent: Sendable {
    public let type: String
    public let timestamp: Int64
    public let payload: WebSocketEventPayload

    public init(type: String, timestamp: Int64, payload: WebSocketEventPayload) {
        self.type = type
        self.timestamp = timestamp
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case timestamp
        case data
    }

    public static func decode(from data: Data) throws -> WebSocketEvent {
        let decoder = JSONDecoder()

        struct Header: Decodable {
            let type: String
            let timestamp: Int64
        }

        let header = try decoder.decode(Header.self, from: data)

        // Parse nested data based on event type
        struct Envelope<T: Decodable>: Decodable {
            let type: String
            let timestamp: Int64
            let data: T
        }

        switch header.type {
        case "host_tick":
            let env = try decoder.decode(Envelope<HostOverview>.self, from: data)
            return WebSocketEvent(type: header.type, timestamp: header.timestamp, payload: .hostTick(env.data))
        case "container_event":
            let env = try decoder.decode(Envelope<ContainerEventData>.self, from: data)
            return WebSocketEvent(type: header.type, timestamp: header.timestamp, payload: .containerEvent(env.data))
        default:
            return WebSocketEvent(type: header.type, timestamp: header.timestamp, payload: .raw(data))
        }
    }
}
