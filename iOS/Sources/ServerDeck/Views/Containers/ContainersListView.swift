import SwiftUI

public struct ContainersListView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ContainersViewModel

    public init(apiClient: APIClient, webSocketManager: WebSocketManager) {
        _viewModel = StateObject(wrappedValue: ContainersViewModel(apiClient: apiClient, webSocketManager: webSocketManager))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search containers or stacks...", text: $viewModel.searchQuery)
                        .textFieldStyle(.plain)

                    if !viewModel.searchQuery.isEmpty {
                        Button {
                            viewModel.searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Stack Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.availableStacks, id: \.self) { stack in
                            Button {
                                viewModel.selectedStack = stack
                                HapticManager.selection()
                            } label: {
                                Text(stack)
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        viewModel.selectedStack == stack
                                        ? Color.accentColor
                                        : Color.primary.opacity(0.06)
                                    )
                                    .foregroundColor(
                                        viewModel.selectedStack == stack
                                        ? .white
                                        : .primary
                                    )
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                // Status Filter Segmented Control
                Picker("Status Filter", selection: $viewModel.selectedFilterState) {
                    ForEach(ContainerFilterState.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

                Divider()

                // Containers Scroll List
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if viewModel.filteredContainers.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "shippingbox")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary.opacity(0.5))
                                    .padding(.top, 40)

                                Text("No containers match your filter")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(viewModel.filteredContainers) { container in
                                NavigationLink {
                                    ContainerDetailView(container: container, apiClient: appState.apiClient)
                                } label: {
                                    ContainerRowView(
                                        container: container,
                                        onRestart: {
                                            Task { await viewModel.restartContainer(id: container.id) }
                                        },
                                        onStart: {
                                            Task { await viewModel.startContainer(id: container.id) }
                                        },
                                        onStop: {
                                            Task { await viewModel.stopContainer(id: container.id) }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await viewModel.loadContainers(showLoadingIndicator: false)
                }
            }
            .navigationTitle("Containers")
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
            .task {
                await viewModel.loadContainers()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Loading containers...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
            .alert(
                "Container Action",
                isPresented: Binding(
                    get: { viewModel.alertMessage != nil },
                    set: { if !$0 { viewModel.alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                if let msg = viewModel.alertMessage {
                    Text(msg)
                }
            }
        }
    }
}
