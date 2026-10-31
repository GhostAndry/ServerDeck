import SwiftUI

public enum Theme {
    // MARK: - Brand & Status Colors
    public static let accent = Color.accentColor
    public static let success = Color.green
    public static let warning = Color.orange
    public static let danger = Color.red
    public static let secondaryText = Color.secondary

    public static let terminalBackground = Color(red: 0.07, green: 0.08, blue: 0.10)
    public static let terminalText = Color(red: 0.22, green: 0.88, blue: 0.52)
    public static let terminalTimestamp = Color(red: 0.45, green: 0.55, blue: 0.65)

    #if canImport(UIKit)
    public static let systemBackground = Color(uiColor: .systemBackground)
    #elseif canImport(AppKit)
    public static let systemBackground = Color(nsColor: .windowBackgroundColor)
    #else
    public static let systemBackground = Color.black
    #endif

    // MARK: - Metric Thresholds
    public static func colorForUsage(_ percent: Double) -> Color {
        if percent >= 85.0 {
            return danger
        } else if percent >= 70.0 {
            return warning
        } else {
            return success
        }
    }

    public static func colorForState(_ state: String, health: String? = nil) -> Color {
        if health?.lowercased() == "unhealthy" {
            return danger
        }

        switch state.lowercased() {
        case "running":
            return success
        case "restarting":
            return warning
        case "paused":
            return Color.yellow
        case "exited", "dead", "stopped":
            return Color.secondary
        default:
            return Color.secondary
        }
    }

    public static func colorForServiceStatus(_ status: String) -> Color {
        switch status.lowercased() {
        case "online":
            return success
        case "degraded":
            return warning
        case "offline":
            return danger
        default:
            return Color.secondary
        }
    }
}
