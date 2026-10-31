import Foundation
import Combine

public enum WebSocketState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var statusDescription: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Live (Connected)"
        case .reconnecting(let attempt):
            return "Reconnecting (\(attempt))..."
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
}

private final class WebSocketDelegateHandler: NSObject, URLSessionWebSocketDelegate, Sendable {
    let allowInsecureSSL: Bool

    init(allowInsecureSSL: Bool) {
        self.allowInsecureSSL = allowInsecureSSL
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if allowInsecureSSL,
           challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let serverTrust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: serverTrust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

@MainActor
public final class WebSocketManager: ObservableObject {
    @Published public private(set) var state: WebSocketState = .disconnected
    @Published public private(set) var latestHostOverview: HostOverview?
    @Published public private(set) var latestContainerEvent: ContainerEventData?

    private var config: ServerConfig
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var isIntentionallyClosed = false
    private var reconnectAttempt = 0
    private var reconnectTask: Task<Void, Never>?
    private var candidateIndex = 0

    public init(config: ServerConfig = ServerConfig()) {
        self.config = config
    }

    private var candidateURLs: [URL] {
        var list: [URL] = []
        if let local = config.wsBaseURL(for: config.cleanLocalURL) {
            list.append(local)
        }
        if let ts = config.wsBaseURL(for: config.cleanTailscaleURL), !list.contains(ts) {
            list.append(ts)
        }
        if list.isEmpty, let fallback = config.wsBaseURL {
            list.append(fallback)
        }
        return list
    }

    public func updateConfig(_ newConfig: ServerConfig) {
        self.config = newConfig
        self.candidateIndex = 0
        if state.isConnected {
            disconnect()
            connect()
        }
    }

    public func connect(preferredURL: URL? = nil) {
        guard !config.useMockData else {
            state = .connected
            latestHostOverview = MockDataProvider.sampleHostOverview
            return
        }

        var candidates = candidateURLs
        if let preferred = preferredURL, let preferredWS = config.wsBaseURL(for: preferred) {
            candidates.removeAll { $0 == preferredWS }
            candidates.insert(preferredWS, at: 0)
        }

        guard !candidates.isEmpty else {
            state = .error("Invalid WebSocket URL")
            return
        }

        let wsBaseURL = candidates[candidateIndex % candidates.count]

        isIntentionallyClosed = false
        reconnectTask?.cancel()

        var components = URLComponents(url: wsBaseURL.appendingPathComponent("api/v1/events"), resolvingAgainstBaseURL: true)
        let tokenToUse = config.token.trimmingCharacters(in: .whitespaces).isEmpty ? "serverdeck-secret-2026" : config.token
        components?.queryItems = [URLQueryItem(name: "token", value: tokenToUse)]

        guard let wsURL = components?.url else {
            state = .error("Failed to construct WebSocket URL")
            return
        }

        var request = URLRequest(url: wsURL)
        request.timeoutInterval = 8.0
        request.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
        request.setValue(tokenToUse, forHTTPHeaderField: "X-API-Key")

        let delegate = WebSocketDelegateHandler(allowInsecureSSL: config.allowInsecureSSL)
        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 10.0
        let newSession = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: .main)
        self.session = newSession

        let task = newSession.webSocketTask(with: request)
        self.webSocketTask = task

        state = .connecting
        task.resume()

        listenForMessages()
        pingPeriodically()
    }

    public func disconnect() {
        isIntentionallyClosed = true
        reconnectTask?.cancel()
        reconnectAttempt = 0

        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil

        state = .disconnected
    }

    private func listenForMessages() {
        guard let task = webSocketTask else { return }

        task.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                switch result {
                case .success(let message):
                    if self.state != .connected {
                        self.state = .connected
                        self.reconnectAttempt = 0
                    }
                    self.handleMessage(message)
                    self.listenForMessages()

                case .failure(let error):
                    if !self.isIntentionallyClosed {
                        self.handleDisconnection(error: error)
                    }
                }
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let rawData: Data?
        switch message {
        case .data(let data):
            rawData = data
        case .string(let text):
            rawData = text.data(using: .utf8)
        @unknown default:
            rawData = nil
        }

        guard let data = rawData else { return }

        do {
            let event = try WebSocketEvent.decode(from: data)
            switch event.payload {
            case .hostTick(let overview):
                self.latestHostOverview = overview
            case .containerEvent(let eventData):
                self.latestContainerEvent = eventData
            case .raw:
                break
            }
        } catch {
            // Decoding failed or unrecognized payload
        }
    }

    private func handleDisconnection(error: Error) {
        webSocketTask?.cancel(with: .abnormalClosure, reason: nil)
        webSocketTask = nil

        guard !isIntentionallyClosed else {
            state = .disconnected
            return
        }

        // Cycle through LAN and Tailscale
        candidateIndex += 1
        reconnectAttempt += 1
        state = .reconnecting(attempt: reconnectAttempt)

        let delay = min(pow(2.0, Double(reconnectAttempt)), 15.0)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self = self, !self.isIntentionallyClosed else { return }
            self.connect()
        }
    }

    private func pingPeriodically() {
        Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard let self = self, self.state.isConnected, let task = self.webSocketTask else { break }
                task.sendPing { error in
                    if let _ = error {
                        Task { @MainActor [weak self] in
                            self?.handleDisconnection(error: error!)
                        }
                    }
                }
            }
        }
    }
}
