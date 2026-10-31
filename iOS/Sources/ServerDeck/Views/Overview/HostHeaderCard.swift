import SwiftUI

public struct HostHeaderCard: View {
    let hostname: String
    let os: String
    let uptime: String
    let isConnected: Bool

    public init(hostname: String, os: String, uptime: String, isConnected: Bool) {
        self.hostname = hostname
        self.os = os
        self.uptime = uptime
        self.isConnected = isConnected
    }

    public var body: some View {
        CardView {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(hostname)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)

                        StatusBadgeView(
                            title: isConnected ? "ONLINE" : "OFFLINE",
                            color: isConnected ? Theme.success : Theme.danger,
                            isPulsing: isConnected
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text(os)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text("UPTIME")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Text(uptime)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
