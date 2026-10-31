import SwiftUI
import Combine

public enum ContainerFilterState: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case running = "Running"
    case stopped = "Stopped"
    case unhealthy = "Unhealthy"

    public var id: String { rawValue }
}

@MainActor
public final class ContainersViewModel: ObservableObject {
    @Published public private(set) var containers: [DockerContainer] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var isRefreshing: Bool = false
    @Published public var searchQuery: String = ""
    @Published public var selectedStack: String = "All"
    @Published public var selectedFilterState: ContainerFilterState = .all
    @Published public var actionInProgressId: String?
    @Published public var errorMessage: String?
    @Published public var alertMessage: String?

    private let apiClient: APIClient
    private let webSocketManager: WebSocketManager
    private var cancellables = Set<AnyCancellable>()

    public init(apiClient: APIClient, webSocketManager: WebSocketManager) {
        self.apiClient = apiClient
        self.webSocketManager = webSocketManager

        // Listen for live container events from WebSocket
        webSocketManager.$latestContainerEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.handleLiveEvent(event)
            }
            .store(in: &cancellables)
    }

    public func loadContainers(showLoadingIndicator: Bool = true) async {
        if showLoadingIndicator && containers.isEmpty {
            isLoading = true
        } else {
            isRefreshing = true
        }
        errorMessage = nil

        do {
            let fetched = try await apiClient.fetchContainers()
            self.containers = fetched
        } catch {
            self.errorMessage = error.localizedDescription
        }

        isLoading = false
        isRefreshing = false
    }

    public var availableStacks: [String] {
        var stacks = Set<String>()
        for container in containers {
            if let stack = container.stack, !stack.isEmpty {
                stacks.insert(stack)
            }
        }
        return ["All"] + stacks.sorted()
    }

    public var filteredContainers: [DockerContainer] {
        containers.filter { container in
            // Search filter
            if !searchQuery.isEmpty {
                let query = searchQuery.lowercased()
                let matchesName = container.name.lowercased().contains(query)
                let matchesImage = container.image.lowercased().contains(query)
                let matchesId = container.id.lowercased().contains(query)
                let matchesStack = container.stack?.lowercased().contains(query) ?? false
                guard matchesName || matchesImage || matchesId || matchesStack else {
                    return false
                }
            }

            // Stack filter
            if selectedStack != "All" {
                guard container.stack == selectedStack else {
                    return false
                }
            }

            // State filter
            switch selectedFilterState {
            case .all:
                return true
            case .running:
                return container.isRunning
            case .stopped:
                return !container.isRunning
            case .unhealthy:
                return container.isUnhealthy
            }
        }
    }

    // MARK: - Container Actions

    public func startContainer(id: String) async {
        actionInProgressId = id
        HapticManager.light()
        do {
            let response = try await apiClient.startContainer(id: id)
            self.alertMessage = response.message
            HapticManager.success()
            await loadContainers(showLoadingIndicator: false)
        } catch {
            self.errorMessage = error.localizedDescription
            HapticManager.error()
        }
        actionInProgressId = nil
    }

    public func stopContainer(id: String) async {
        actionInProgressId = id
        HapticManager.light()
        do {
            let response = try await apiClient.stopContainer(id: id)
            self.alertMessage = response.message
            HapticManager.success()
            await loadContainers(showLoadingIndicator: false)
        } catch {
            self.errorMessage = error.localizedDescription
            HapticManager.error()
        }
        actionInProgressId = nil
    }

    public func restartContainer(id: String) async {
        actionInProgressId = id
        HapticManager.medium()
        do {
            let response = try await apiClient.restartContainer(id: id)
            self.alertMessage = response.message
            HapticManager.success()
            await loadContainers(showLoadingIndicator: false)
        } catch {
            self.errorMessage = error.localizedDescription
            HapticManager.error()
        }
        actionInProgressId = nil
    }

    private func handleLiveEvent(_ event: ContainerEventData) {
        if let index = containers.firstIndex(where: { $0.id == event.containerId || $0.name == event.containerId }) {
            let existing = containers[index]
            let updated = DockerContainer(
                id: existing.id,
                name: existing.name,
                image: existing.image,
                state: event.status,
                status: "Updated via \(event.action)",
                health: existing.health,
                stack: existing.stack,
                createdAt: existing.createdAt,
                ports: existing.ports,
                cpuPercent: existing.cpuPercent,
                memoryUsageBytes: existing.memoryUsageBytes,
                memoryLimitBytes: existing.memoryLimitBytes
            )
            containers[index] = updated
        }
    }
}
