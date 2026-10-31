import Foundation

public struct ServerConfig: Codable, Sendable, Hashable {
    public var localURL: String
    public var tailscaleURL: String
    public var token: String
    public var allowInsecureSSL: Bool
    public var useMockData: Bool
    public var requireBiometrics: Bool

    public init(
        localURL: String = "http://10.0.0.99:8080",
        tailscaleURL: String = "http://100.75.107.88:8080",
        token: String = "serverdeck-secret-2026",
        allowInsecureSSL: Bool = true,
        useMockData: Bool = false,
        requireBiometrics: Bool = false
    ) {
        self.localURL = localURL
        self.tailscaleURL = tailscaleURL
        self.token = token
        self.allowInsecureSSL = allowInsecureSSL
        self.useMockData = useMockData
        self.requireBiometrics = requireBiometrics
    }

    // Backward compatibility for single URL
    public var url: String {
        get {
            if !localURL.isEmpty { return localURL }
            if !tailscaleURL.isEmpty { return tailscaleURL }
            return "http://10.0.0.99:8080"
        }
        set {
            if newValue.contains("100.") || newValue.contains("tailscale") {
                tailscaleURL = newValue
            } else {
                localURL = newValue
            }
        }
    }

    public static func cleanURL(from raw: String) -> URL? {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if !trimmed.lowercased().hasPrefix("http://") && !trimmed.lowercased().hasPrefix("https://") {
            trimmed = "http://" + trimmed
        }
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return URL(string: trimmed)
    }

    public var cleanLocalURL: URL? {
        Self.cleanURL(from: localURL)
    }

    public var cleanTailscaleURL: URL? {
        Self.cleanURL(from: tailscaleURL)
    }

    public var cleanBaseURL: URL? {
        cleanLocalURL ?? cleanTailscaleURL
    }

    public func wsBaseURL(for httpURL: URL?) -> URL? {
        guard let url = httpURL ?? cleanBaseURL else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        if components?.scheme == "https" {
            components?.scheme = "wss"
        } else {
            components?.scheme = "ws"
        }
        return components?.url
    }

    public var wsBaseURL: URL? {
        wsBaseURL(for: cleanBaseURL)
    }

    // MARK: - Codable
    enum CodingKeys: String, CodingKey {
        case localURL = "local_url"
        case tailscaleURL = "tailscale_url"
        case legacyURL = "url"
        case token
        case allowInsecureSSL = "allow_insecure_ssl"
        case useMockData = "use_mock_data"
        case requireBiometrics = "require_biometrics"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let legacy = try container.decodeIfPresent(String.self, forKey: .legacyURL)
        let local = try container.decodeIfPresent(String.self, forKey: .localURL)
        let tailscale = try container.decodeIfPresent(String.self, forKey: .tailscaleURL)

        self.localURL = local ?? (legacy?.contains("100.") == false ? legacy ?? "http://10.0.0.99:8080" : "http://10.0.0.99:8080")
        self.tailscaleURL = tailscale ?? (legacy?.contains("100.") == true ? legacy ?? "http://100.75.107.88:8080" : "http://100.75.107.88:8080")
        self.token = try container.decodeIfPresent(String.self, forKey: .token) ?? "serverdeck-secret-2026"
        self.allowInsecureSSL = try container.decodeIfPresent(Bool.self, forKey: .allowInsecureSSL) ?? true
        self.useMockData = try container.decodeIfPresent(Bool.self, forKey: .useMockData) ?? false
        self.requireBiometrics = try container.decodeIfPresent(Bool.self, forKey: .requireBiometrics) ?? false
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(localURL, forKey: .localURL)
        try container.encode(tailscaleURL, forKey: .tailscaleURL)
        try container.encode(localURL, forKey: .legacyURL)
        try container.encode(token, forKey: .token)
        try container.encode(allowInsecureSSL, forKey: .allowInsecureSSL)
        try container.encode(useMockData, forKey: .useMockData)
        try container.encode(requireBiometrics, forKey: .requireBiometrics)
    }
}
