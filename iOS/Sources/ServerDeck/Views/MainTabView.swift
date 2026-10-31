import SwiftUI

public struct MainTabView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        TabView(selection: $appState.selectedTab) {
            OverviewView(apiClient: appState.apiClient, webSocketManager: appState.webSocketManager)
                .tabItem {
                    Label("Overview", systemImage: "gauge.with.needle.fill")
                }
                .tag(0)

            ContainersListView(apiClient: appState.apiClient, webSocketManager: appState.webSocketManager)
                .tabItem {
                    Label("Containers", systemImage: "shippingbox.fill")
                }
                .tag(1)

            ServicesView(apiClient: appState.apiClient)
                .tabItem {
                    Label("Services", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)

            SettingsView(config: appState.config)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .sheet(isPresented: $appState.showQuickActions) {
            QuickActionsSheet()
        }
    }
}
