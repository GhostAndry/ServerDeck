import Foundation

public enum Formatters {
    public static func formatBytes(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "0 B" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .binary)
    }

    public static func formatRate(_ bytesPerSec: Double) -> String {
        guard bytesPerSec > 0 else { return "0 B/s" }
        let formatted = ByteCountFormatter.string(fromByteCount: Int64(bytesPerSec), countStyle: .binary)
        return "\(formatted)/s"
    }

    public static func formatUptime(_ seconds: Int64) -> String {
        guard seconds > 0 else { return "0m" }

        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public static func formatPercent(_ percent: Double, decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f%%", percent)
    }

    public static func formatDate(_ timestamp: Int64) -> String {
        guard timestamp > 0 else { return "Unknown" }
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
