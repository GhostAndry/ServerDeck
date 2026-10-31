import SwiftUI

public struct OverviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: OverviewViewModel
    @State private var showTerminal = false

    public init(apiClient: APIClient, webSocketManager: WebSocketManager) {
        _viewModel = StateObject(wrappedValue: OverviewViewModel(apiClient: apiClient, webSocketManager: webSocketManager))
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Connection / Demo banner
                    ConnectionStatusBanner(
                        state: appState.webSocketManager.state,
                        isMockData: appState.config.useMockData
                    )

                    VStack(spacing: 16) {
                        // Host Header Card
                        HostHeaderCard(
                            hostname: viewModel.hostname,
                            os: viewModel.osDescription,
                            uptime: viewModel.formattedUptime,
                            isConnected: appState.webSocketManager.state.isConnected || appState.config.useMockData
                        )

                        // CPU & RAM Dual Gauges
                        HStack(spacing: 12) {
                            StatGaugeView(
                                title: "CPU Load",
                                percent: viewModel.cpuUsagePercent,
                                detailText: viewModel.cpuTemperature != "--" ? "\(viewModel.cpuTemperature) • \(viewModel.cpuCores) Cores" : "\(viewModel.cpuCores) Cores",
                                icon: "cpu"
                            )

                            StatGaugeView(
                                title: "RAM Usage",
                                percent: viewModel.memoryUsagePercent,
                                detailText: "\(viewModel.formattedMemoryUsed) / \(viewModel.formattedMemoryTotal)",
                                icon: "memorychip"
                            )
                        }

                        // Container Summary Badges
                        ContainerSummaryBadgesView(summary: viewModel.containersSummary) { _ in
                            appState.selectedTab = 1 // Switch to Containers tab
                        }

                        // Network Throughput Card
                        NetworkMetricCard(
                            rxRate: viewModel.networkRxRate,
                            txRate: viewModel.networkTxRate
                        )

                        // Disks (Root / and /mnt/DATA)
                        DiskMetricCard(disks: viewModel.disks)

                        // Quick Management & Host Action Bar
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "bolt.horizontal.fill")
                                        .foregroundColor(.orange)
                                    Text("GESTIONE RAPIDA & HOST")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }

                                HStack(spacing: 8) {
                                    Button {
                                        appState.showQuickActions = true
                                        HapticManager.light()
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "power")
                                                .foregroundColor(.red)
                                            Text("Host Power")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        appState.showQuickActions = true
                                        HapticManager.light()
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.cyan)
                                            Text("Prune")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.cyan.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        showTerminal = true
                                        HapticManager.light()
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: "terminal.fill")
                                                .foregroundColor(.green)
                                            Text("Terminale")
                                                .font(.system(size: 12, weight: .semibold))
                                        }
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("ServerDeck")
            .navigationTitleModeLarge()
            .toolbar {
                ToolbarItem(placement: .trailingAction) {
                    Button {
                        appState.showQuickActions = true
                        HapticManager.light()
                    } label: {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            .sheet(isPresented: $showTerminal) {
                HostTerminalSheet(apiClient: appState.apiClient)
            }
            .refreshable {
                await viewModel.loadOverview(showLoadingIndicator: false)
            }
            .task {
                await viewModel.loadOverview()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Connecting to host...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
}
