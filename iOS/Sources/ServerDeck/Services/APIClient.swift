import Foundation

public enum APIError: LocalizedError, Sendable {
    case invalidURL
    case unauthorized
    case httpError(statusCode: Int, message: String)
    case decodingError(String)
    case networkError(String)
    case serverError(String)
    case emptyResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Configurazione URL server non valida."
        case .unauthorized:
            return "Non autorizzato (401). Verifica il token API nelle Impostazioni."
        case .httpError(let statusCode, let message):
            return "Errore HTTP \(statusCode): \(message)"
        case .decodingError(let details):
            return "Errore di decodifica della risposta: \(details)"
        case .networkError(let details):
            return "Errore di connessione: \(details)"
        case .serverError(let message):
            return message
        case .emptyResponse:
            return "Il server ha restituito una risposta vuota."
        }
    }
}

// Delegate that allows bypassing self-signed certificates when configured
private final class InsecureSSLDelegate: NSObject, URLSessionDelegate, Sendable {
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

public actor APIClient {
    public enum ConnectionMode: String, Sendable {
        case localLAN = "LAN (10.0.0.99)"
        case tailscale = "Tailscale (100.75.107.88)"
        case custom = "Personalizzato"
        case mock = "Modalità Mock"
        case disconnected = "Non connesso"
    }

    public var config: ServerConfig
    public private(set) var activeBaseURL: URL?
    public private(set) var activeMode: ConnectionMode = .disconnected

    private var session: URLSession
    private var fastSession: URLSession

    public init(config: ServerConfig = ServerConfig()) {
        self.config = config
        let delegate = InsecureSSLDelegate(allowInsecureSSL: config.allowInsecureSSL)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 8.0
        sessionConfig.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        let fastConfig = URLSessionConfiguration.default
        fastConfig.timeoutIntervalForRequest = 1.5
        fastConfig.timeoutIntervalForResource = 2.0
        self.fastSession = URLSession(configuration: fastConfig, delegate: delegate, delegateQueue: nil)
    }

    public func updateConfig(_ newConfig: ServerConfig) {
        self.config = newConfig
        self.activeBaseURL = nil
        self.activeMode = .disconnected

        let delegate = InsecureSSLDelegate(allowInsecureSSL: newConfig.allowInsecureSSL)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = 8.0
        sessionConfig.timeoutIntervalForResource = 15.0
        self.session = URLSession(configuration: sessionConfig, delegate: delegate, delegateQueue: nil)

        let fastConfig = URLSessionConfiguration.default
        fastConfig.timeoutIntervalForRequest = 1.5
        fastConfig.timeoutIntervalForResource = 2.0
        self.fastSession = URLSession(configuration: fastConfig, delegate: delegate, delegateQueue: nil)
    }

    public func getActiveBaseURL() -> URL? {
        activeBaseURL
    }

    // Resolves whether we are currently reachable via LAN or Tailscale
    public func resolveActiveBaseURL() async -> URL {
        if config.useMockData {
            activeMode = .mock
            let mockURL = URL(string: "http://mock.local")!
            activeBaseURL = mockURL
            return mockURL
        }

        // 1. Prova prima l'IP LAN 10.0.0.99 con timeout rapido (1.5s)
        if let local = config.cleanLocalURL {
            let isReachable = await executeWithTimeout(seconds: 1.5) {
                (try? await self.performRawHealthCheck(baseURL: local)) == true
            }
            if isReachable == true {
                self.activeBaseURL = local
                self.activeMode = .localLAN
                return local
            }
        }

        // 2. Se la LAN non risponde in 1.5s, passa direttamente a Tailscale (100.75.107.88)
        if let ts = config.cleanTailscaleURL {
            self.activeBaseURL = ts
            self.activeMode = .tailscale
            return ts
        }

        let fallback = config.cleanBaseURL ?? URL(string: "http://100.75.107.88:8080")!
        self.activeBaseURL = fallback
        return fallback
    }

    // MARK: - Generic Request Helper
    private func executeRequest<T: Decodable>(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil
    ) async throws -> T {
        if config.useMockData {
            activeMode = .mock
            return try mockResponse(for: path)
        }

        // Se abbiamo già un endpoint attivo, proviamolo prima
        if let current = activeBaseURL {
            do {
                return try await performRequestOnBase(
                    baseURL: current,
                    path: path,
                    method: method,
                    queryItems: queryItems,
                    body: body
                )
            } catch {
                if case APIError.unauthorized = error {
                    throw error
                }
                // Se l'endpoint attivo fallisce (es. cambio rete da LAN a Tailscale), azzeriamo e ri-risolviamo
                self.activeBaseURL = nil
            }
        }

        // Risolvi l'endpoint (LAN o Tailscale)
        let resolvedURL = await resolveActiveBaseURL()
        return try await performRequestOnBase(
            baseURL: resolvedURL,
            path: path,
            method: method,
            queryItems: queryItems,
            body: body
        )
    }

    private func performRequestOnBase<T: Decodable>(
        baseURL: URL,
        path: String,
        method: String,
        queryItems: [URLQueryItem]?,
        body: Data?
    ) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        if let queryItems = queryItems, !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let tokenToUse = config.token.trimmingCharacters(in: .whitespaces).isEmpty ? "serverdeck-secret-2026" : config.token
        request.setValue("Bearer \(tokenToUse)", forHTTPHeaderField: "Authorization")
        request.setValue(tokenToUse, forHTTPHeaderField: "X-API-Key")

        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.serverError("Risposta HTTP non valida.")
        }

        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        guard !data.isEmpty else {
            throw APIError.emptyResponse
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - API Endpoints

    public func fetchHostOverview() async throws -> HostOverview {
        try await executeRequest(path: "api/v1/host")
    }

    public func fetchContainers() async throws -> [DockerContainer] {
        try await executeRequest(path: "api/v1/containers")
    }

    public func fetchContainerStats(id: String) async throws -> ContainerStats {
        try await executeRequest(path: "api/v1/containers/\(id)/stats")
    }

    public func fetchContainerLogs(id: String, tail: Int = 200, timestamps: Bool = true) async throws -> ContainerLogs {
        let queryItems = [
            URLQueryItem(name: "tail", value: "\(tail)"),
            URLQueryItem(name: "timestamps", value: "\(timestamps)")
        ]
        return try await executeRequest(path: "api/v1/containers/\(id)/logs", queryItems: queryItems)
    }

    public func startContainer(id: String) async throws -> ActionResponse {
        try await executeRequest(path: "api/v1/containers/\(id)/start", method: "POST")
    }

    public func stopContainer(id: String) async throws -> ActionResponse {
        try await executeRequest(path: "api/v1/containers/\(id)/stop", method: "POST")
    }

    public func restartContainer(id: String) async throws -> ActionResponse {
        try await executeRequest(path: "api/v1/containers/\(id)/restart", method: "POST")
    }

    public func fetchServices() async throws -> [ServiceItem] {
        try await executeRequest(path: "api/v1/services")
    }

    public struct AddServicePayload: Codable, Sendable {
        public let name: String
        public let url: String
        public let icon: String
        public let category: String

        public init(name: String, url: String, icon: String, category: String) {
            self.name = name
            self.url = url
            self.icon = icon
            self.category = category
        }
    }

    public func addService(name: String, url: String, icon: String, category: String) async throws -> ServiceItem {
        let payload = AddServicePayload(name: name, url: url, icon: icon, category: category)
        let body = try JSONEncoder().encode(payload)
        return try await executeRequest(path: "api/v1/services", method: "POST", body: body)
    }

    public func deleteService(id: String) async throws -> ActionResponse {
        try await executeRequest(path: "api/v1/services/\(id)", method: "DELETE")
    }

    // MARK: - Host & System Management

    public func rebootHost() async throws -> ActionResponse {
        try await executeRequest(path: "api/v1/host/reboot", method: "POST")
    }

    public func shutdownHost() async throws -> ActionResponse {
        try await executeRequest(path: "api/v1/host/shutdown", method: "POST")
    }

    public func pruneSystem() async throws -> PruneReport {
        try await executeRequest(path: "api/v1/system/prune", method: "POST")
    }

    public func restartUnhealthyContainers() async throws -> RestartUnhealthyResponse {
        try await executeRequest(path: "api/v1/system/restart-unhealthy", method: "POST")
    }

    public func fetchDiagnostics() async throws -> DiagnosticReport {
        try await executeRequest(path: "api/v1/system/diagnostics")
    }

    public struct ExecPayload: Codable, Sendable {
        public let command: String
        public init(command: String) {
            self.command = command
        }
    }

    public func executeHostCommand(_ command: String) async throws -> ExecResult {
        let payload = ExecPayload(command: command)
        let body = try JSONEncoder().encode(payload)
        return try await executeRequest(path: "api/v1/host/exec", method: "POST", body: body)
    }

    // Probes LAN first, then Tailscale
    public func testConnection() async throws -> (success: Bool, latencyMs: Int, modeDescription: String) {
        if config.useMockData {
            activeMode = .mock
            return (true, 5, "Modalità Mock (Offline)")
        }

        // 1. Prova prima l'IP locale 10.0.0.99
        if let local = config.cleanLocalURL {
            let start = Date()
            let responded = await executeWithTimeout(seconds: 1.5) {
                (try? await self.performRawHealthCheck(baseURL: local)) == true
            }
            if responded == true {
                let latency = max(1, Int(Date().timeIntervalSince(start) * 1000))
                self.activeBaseURL = local
                self.activeMode = .localLAN
                return (true, latency, "LAN (10.0.0.99)")
            }
        }

        // 2. Prova poi l'IP Tailscale 100.75.107.88
        if let ts = config.cleanTailscaleURL {
            let start = Date()
            let responded = await executeWithTimeout(seconds: 3.5) {
                (try? await self.performRawHealthCheck(baseURL: ts)) == true
            }
            if responded == true {
                let latency = max(1, Int(Date().timeIntervalSince(start) * 1000))
                self.activeBaseURL = ts
                self.activeMode = .tailscale
                return (true, latency, "Tailscale (100.75.107.88)")
            }
        }

        throw APIError.networkError("Impossibile raggiungere il server né via LAN (10.0.0.99) né via Tailscale.")
    }

    private func performRawHealthCheck(baseURL: URL) async throws -> Bool {
        let healthURL = baseURL.appendingPathComponent("healthz")
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 2.0
        let (data, response) = try await fastSession.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
            return !data.isEmpty
        }
        return false
    }

    private func executeWithTimeout<R: Sendable>(seconds: Double, operation: @Sendable @escaping () async -> R) async -> R? {
        await withTaskGroup(of: R?.self) { group in
            group.addTask {
                await operation()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next()
            group.cancelAll()
            return first ?? nil
        }
    }

    // MARK: - Mock Fallback Helper
    private func mockResponse<T: Decodable>(for path: String) throws -> T {
        if path.hasPrefix("api/v1/host") {
            return MockDataProvider.sampleHostOverview as! T
        } else if path.hasPrefix("api/v1/containers") && path.hasSuffix("/stats") {
            let parts = path.split(separator: "/")
            let containerId = parts.count >= 4 ? String(parts[3]) : "c1a2b3c4d5e6"
            return MockDataProvider.sampleStats(for: containerId) as! T
        } else if path.hasPrefix("api/v1/containers") && path.hasSuffix("/logs") {
            let parts = path.split(separator: "/")
            let containerId = parts.count >= 4 ? String(parts[3]) : "c1a2b3c4d5e6"
            return MockDataProvider.sampleLogs(for: containerId) as! T
        } else if path.hasPrefix("api/v1/containers") && (path.hasSuffix("/start") || path.hasSuffix("/stop") || path.hasSuffix("/restart")) {
            return ActionResponse(success: true, message: "Action completed successfully (Mock)") as! T
        } else if path.hasPrefix("api/v1/containers") {
            return MockDataProvider.sampleContainers as! T
        } else if path.hasPrefix("api/v1/services") {
            if T.self == ServiceItem.self {
                return MockDataProvider.sampleServices.first! as! T
            } else if T.self == ActionResponse.self {
                return ActionResponse(success: true, message: "Service deleted successfully (Mock)") as! T
            }
            return MockDataProvider.sampleServices as! T
        } else if path.hasPrefix("api/v1/host/reboot") {
            return ActionResponse(success: true, message: "Host reboot scheduled in 3 seconds (Mock)") as! T
        } else if path.hasPrefix("api/v1/host/shutdown") {
            return ActionResponse(success: true, message: "Host shutdown scheduled in 3 seconds (Mock)") as! T
        } else if path.hasPrefix("api/v1/system/prune") {
            return MockDataProvider.samplePruneReport as! T
        } else if path.hasPrefix("api/v1/system/restart-unhealthy") {
            return RestartUnhealthyResponse(success: true, restartedCount: 1, containers: ["backup-cron"], message: "Restarted 1 unhealthy container (Mock)") as! T
        } else if path.hasPrefix("api/v1/system/diagnostics") {
            return MockDataProvider.sampleDiagnostics as! T
        } else if path.hasPrefix("api/v1/host/exec") {
            return ExecResult(command: "uname -a", stdout: "Linux srv-01 6.12.113+deb13-amd64 #1 SMP PREEMPT_DYNAMIC Debian x86_64 GNU/Linux\nUptime: 5 days, 0 users\nLoad average: 0.15, 0.08, 0.05", stderr: "", exitCode: 0, durationMs: 14) as! T
        }

        throw APIError.serverError("No mock available for \(path)")
    }
}
