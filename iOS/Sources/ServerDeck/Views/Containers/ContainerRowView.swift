import SwiftUI

public struct ContainerRowView: View {
    let container: DockerContainer
    var onRestart: (() -> Void)? = nil
    var onStart: (() -> Void)? = nil
    var onStop: (() -> Void)? = nil

    public init(
        container: DockerContainer,
        onRestart: (() -> Void)? = nil,
        onStart: (() -> Void)? = nil,
        onStop: (() -> Void)? = nil
    ) {
        self.container = container
        self.onRestart = onRestart
        self.onStart = onStart
        self.onStop = onStop
    }

    private var statusColor: Color {
        Theme.colorForState(container.state, health: container.health)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Top row: status dot + name + stack badge
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 9, height: 9)

                Text(container.cleanName)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)

                if let stack = container.stack, !stack.isEmpty {
                    Text(stack)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.08))
                        .cornerRadius(6)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if container.isUnhealthy {
                    Text("UNHEALTHY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Theme.danger)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.danger.opacity(0.12))
                        .cornerRadius(6)
                } else {
                    Text(container.state.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(statusColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(6)
                }
            }

            // Image subtitle
            Text(container.image)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)

            // Bottom row: Metrics (CPU & RAM) & Port mappings
            HStack(spacing: 12) {
                if container.isRunning {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(Formatters.formatPercent(container.cpuPercent))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "memorychip")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(Formatters.formatBytes(container.memoryUsageBytes))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    }
                }

                Spacer()

                if let firstPort = container.ports.first {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.system(size: 10))
                        Text(firstPort)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(container.isUnhealthy ? Theme.danger.opacity(0.3) : Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
        .contextMenu {
            if container.isRunning {
                Button(role: .destructive) {
                    onStop?()
                } label: {
                    Label("Stop Container", systemImage: "stop.fill")
                }

                Button {
                    onRestart?()
                } label: {
                    Label("Restart Container", systemImage: "arrow.clockwise")
                }
            } else {
                Button {
                    onStart?()
                } label: {
                    Label("Start Container", systemImage: "play.fill")
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if container.isRunning {
                Button {
                    onRestart?()
                } label: {
                    Label("Restart", systemImage: "arrow.clockwise")
                }
                .tint(.orange)

                Button(role: .destructive) {
                    onStop?()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
            } else {
                Button {
                    onStart?()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .tint(.green)
            }
        }
    }
}
