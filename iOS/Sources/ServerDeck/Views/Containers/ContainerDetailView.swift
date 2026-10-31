import SwiftUI

public struct ContainerDetailView: View {
    @StateObject private var viewModel: ContainerDetailViewModel
    @State private var showRestartConfirm = false
    @State private var showStopConfirm = false

    public init(container: DockerContainer, apiClient: APIClient) {
        _viewModel = StateObject(wrappedValue: ContainerDetailViewModel(container: container, apiClient: apiClient))
    }

    private var statusColor: Color {
        Theme.colorForState(viewModel.container.state, health: viewModel.container.health)
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Card
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)

                            Text(viewModel.container.cleanName)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)

                            Spacer()

                            StatusBadgeView(
                                title: viewModel.container.isUnhealthy ? "UNHEALTHY" : viewModel.container.state.uppercased(),
                                color: statusColor,
                                isPulsing: viewModel.container.isRunning
                            )
                        }

                        Text(viewModel.container.image)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)

                        if let stack = viewModel.container.stack {
                            HStack(spacing: 4) {
                                Text("Stack:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(stack)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.primary)
                            }
                        }

                        Text(viewModel.container.status)
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }

                // Action Controls Card
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONTAINER ACTIONS")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)

                        HStack(spacing: 12) {
                            if viewModel.container.isRunning {
                                Button {
                                    showRestartConfirm = true
                                } label: {
                                    Label("Restart", systemImage: "arrow.clockwise")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundColor(.orange)
                                        .cornerRadius(10)
                                }

                                Button {
                                    showStopConfirm = true
                                } label: {
                                    Label("Stop", systemImage: "stop.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Theme.danger.opacity(0.15))
                                        .foregroundColor(Theme.danger)
                                        .cornerRadius(10)
                                }
                            } else {
                                Button {
                                    Task { await viewModel.start() }
                                } label: {
                                    Label("Start", systemImage: "play.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Theme.success.opacity(0.15))
                                        .foregroundColor(Theme.success)
                                        .cornerRadius(10)
                                }
                            }
                        }
                        .disabled(viewModel.isActionLoading)
                        .overlay {
                            if viewModel.isActionLoading {
                                ProgressView()
                            }
                        }
                    }
                }

                // Live Stats Metrics
                if let stats = viewModel.stats {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("LIVE RESOURCE CONSUMPTION")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        HStack(spacing: 12) {
                            StatGaugeView(
                                title: "CPU Usage",
                                percent: stats.cpuPercent,
                                detailText: Formatters.formatPercent(stats.cpuPercent),
                                icon: "cpu"
                            )

                            StatGaugeView(
                                title: "Memory",
                                percent: stats.memoryPercent,
                                detailText: "\(Formatters.formatBytes(stats.memoryUsageBytes)) / \(Formatters.formatBytes(stats.memoryLimitBytes))",
                                icon: "memorychip"
                            )
                        }

                        CardView {
                            VStack(spacing: 10) {
                                HStack {
                                    Text("Network I/O")
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text("RX: \(Formatters.formatBytes(stats.networkRxBytes)) • TX: \(Formatters.formatBytes(stats.networkTxBytes))")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                HStack {
                                    Text("Block Storage I/O")
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text("Read: \(Formatters.formatBytes(stats.blockReadBytes)) • Write: \(Formatters.formatBytes(stats.blockWriteBytes))")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }

                // Port Bindings Card
                if !viewModel.container.ports.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("PORT BINDINGS")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)

                            ForEach(viewModel.container.ports, id: \.self) { port in
                                HStack {
                                    Image(systemName: "arrow.left.arrow.right")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)

                                    Text(port)
                                        .font(.system(size: 13, weight: .semibold, design: .monospaced))

                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                // Terminal Live Logs
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIVE LOG STREAM")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)

                    TerminalLogView(
                        logs: viewModel.logs,
                        searchText: $viewModel.logSearchText,
                        showTimestamps: $viewModel.showTimestamps,
                        autoScroll: $viewModel.autoScroll,
                        onRefresh: {
                            Task { await viewModel.loadLogs() }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .navigationTitle(viewModel.container.cleanName)
        .navigationTitleModeInline()
        .confirmationDialog(
            "Restart Container",
            isPresented: $showRestartConfirm,
            titleVisibility: .visible
        ) {
            Button("Restart \(viewModel.container.cleanName)", role: .none) {
                Task { await viewModel.restart() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to restart container '\(viewModel.container.cleanName)'? Active network connections will be dropped.")
        }
        .confirmationDialog(
            "Stop Container",
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button("Stop \(viewModel.container.cleanName)", role: .destructive) {
                Task { await viewModel.stop() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to stop '\(viewModel.container.cleanName)'? The service will be unreachable until started again.")
        }
        .task {
            await viewModel.loadStats()
            await viewModel.loadLogs()
            viewModel.startStatsPolling()
        }
        .onDisappear {
            viewModel.stopStatsPolling()
        }
    }
}
