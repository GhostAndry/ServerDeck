import Foundation

public struct CPUStats: Codable, Sendable, Hashable {
    public let usagePercent: Double
    public let cores: Int
    public let model: String
    public let temperatureCelsius: Double?

    public init(
        usagePercent: Double,
        cores: Int,
        model: String,
        temperatureCelsius: Double? = nil
    ) {
        self.usagePercent = usagePercent
        self.cores = cores
        self.model = model
        self.temperatureCelsius = temperatureCelsius
    }

    enum CodingKeys: String, CodingKey {
        case usagePercent = "usage_percent"
        case cores
        case model
        case temperatureCelsius = "temperature_celsius"
    }
}
