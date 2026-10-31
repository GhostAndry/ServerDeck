import SwiftUI
import Combine

@MainActor
public final class ServicesViewModel: ObservableObject {
    @Published public private(set) var services: [ServiceItem] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public var selectedCategory: String = "All"
    @Published public var errorMessage: String?

    private let apiClient: APIClient

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public func loadServices(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator && services.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        do {
            let fetched = try await apiClient.fetchServices()
            self.services = fetched
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    public func addService(name: String, url: String, icon: String, category: String) async -> Bool {
        do {
            let _ = try await apiClient.addService(name: name, url: url, icon: icon, category: category)
            await loadServices(showLoadingIndicator: false)
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public func deleteService(id: String) async -> Bool {
        do {
            let _ = try await apiClient.deleteService(id: id)
            services.removeAll { $0.id == id }
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }

    public var categories: [String] {
        var set = Set<String>()
        for s in services {
            set.insert(s.category)
        }
        return ["All"] + set.sorted()
    }

    public var filteredServices: [ServiceItem] {
        if selectedCategory == "All" {
            return services
        }
        return services.filter { $0.category == selectedCategory }
    }
}
