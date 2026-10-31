import SwiftUI

public struct ServicesView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel: ServicesViewModel
    @State private var showAddServiceSheet: Bool = false
    @State private var serviceToDelete: ServiceItem? = nil

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 14)
    ]

    public init(apiClient: APIClient) {
        _viewModel = StateObject(wrappedValue: ServicesViewModel(apiClient: apiClient))
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Category Filter Pills
                if viewModel.categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.categories, id: \.self) { cat in
                                Button {
                                    viewModel.selectedCategory = cat
                                    HapticManager.selection()
                                } label: {
                                    Text(cat)
                                        .font(.system(size: 13, weight: .semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            viewModel.selectedCategory == cat
                                            ? Color.accentColor
                                            : Color.primary.opacity(0.06)
                                        )
                                        .foregroundColor(
                                            viewModel.selectedCategory == cat
                                            ? .white
                                            : .primary
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    Divider()
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(viewModel.filteredServices) { service in
                            ServiceCardView(service: service) {
                                if let url = URL(string: service.url) {
                                    openURL(url)
                                    HapticManager.light()
                                }
                            } onDelete: {
                                serviceToDelete = service
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await viewModel.loadServices(showLoadingIndicator: false)
                }
            }
            .navigationTitle("Services")
            .navigationTitleModeLarge()
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        showAddServiceSheet = true
                        HapticManager.light()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }

                ToolbarItem(placement: .primaryAction) {
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
            .sheet(isPresented: $showAddServiceSheet) {
                AddServiceSheet(viewModel: viewModel)
            }
            .confirmationDialog(
                "Elimina Servizio",
                isPresented: Binding(
                    get: { serviceToDelete != nil },
                    set: { if !$0 { serviceToDelete = nil } }
                ),
                presenting: serviceToDelete
            ) { svc in
                Button("Elimina \(svc.name)", role: .destructive) {
                    Task {
                        _ = await viewModel.deleteService(id: svc.id)
                        HapticManager.success()
                    }
                }
                Button("Annulla", role: .cancel) {}
            } message: { svc in
                Text("Vuoi davvero rimuovere \(svc.name) dalla lista dei servizi?")
            }
            .task {
                await viewModel.loadServices()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("Probing services...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }
}
