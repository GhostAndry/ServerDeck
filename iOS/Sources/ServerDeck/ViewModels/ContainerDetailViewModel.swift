import SwiftUI
import Combine

@MainActor
public final class ContainerDetailViewModel: ObservableObject {
    @Published public private(set) var container: DockerContainer
    @Published public private(set) var stats: ContainerStats?
    @Published public private(set) var logs: [String] = []

    @Published public var logSearchText: String = ""
    @Published public var showTimestamps: Bool = true
    @Published public var autoScroll: Bool = true
    @Published public var tailCount: Int = 200

    @Published public private(set) var isStatsLoading: Bool = false
    @Published public private(set) var isLogsLoading: Bool = false
    @Published public private(set) var isActionLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var alertMessage: String?

    private let apiClient: APIClient
    private var statsTask: Task<Void, Never>?

    public init(container: DockerContainer, apiClient: APIClient) {
        self.container = container
        self.apiClient = apiClient
    }

    public func startStatsPolling() {
        statsTask?.cancel()
        statsTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { return }
                await self.loadStats()
                try? await Task.sleep(nanoseconds: 3_000_000_000) // Poll every 3 seconds
            }
        }
    }

    public func stopStatsPolling() {
        statsTask?.cancel()
        statsTask = nil
    }

    public func loadStats() async {
        isStatsLoading = stats == nil
        do {
            let fetchedStats = try await apiClient.fetchContainerStats(id: container.id)
            self.stats = fetchedStats
        } catch {
            // Silently continue polling or record
        }
        isStatsLoading = false
    }

    public func loadLogs() async {
        isLogsLoading = logs.isEmpty
        errorMessage = nil
        do {
            let fetchedLogs = try await apiClient.fetchContainerLogs(
                id: container.id,
                tail: tailCount,
                timestamps: showTimestamps
            )
            self.logs = fetchedLogs.lines
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLogsLoading = false
    }

    public var filteredLogs: [String] {
        if logSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return logs
        }
        let query = logSearchText.lowercased()
        return logs.filter { $0.lowercased().contains(query) }
    }

    // MARK: - Actions

    public func start() async {
        isActionLoading = true
        HapticManager.light()
        do {
            let res = try await apiClient.startContainer(id: container.id)
            self.alertMessage = res.message
            HapticManager.success()
            await refreshContainerData()
        } catch {
            self.errorMessage = error.localizedDescription
            HapticManager.error()
        }
        isActionLoading = false
    }

    public func stop() async {
        isActionLoading = true
        HapticManager.light()
        do {
            let res = try await apiClient.stopContainer(id: container.id)
            self.alertMessage = res.message
            HapticManager.success()
            await refreshContainerData()
        } catch {
            self.errorMessage = error.localizedDescription
            HapticManager.error()
        }
        isActionLoading = false
    }

    public func restart() async {
        isActionLoading = true
        HapticManager.medium()
        do {
            let res = try await apiClient.restartContainer(id: container.id)
            self.alertMessage = res.message
            HapticManager.success()
            await refreshContainerData()
        } catch {
            self.errorMessage = error.localizedDescription
            HapticManager.error()
        }
        isActionLoading = false
    }

    private func refreshContainerData() async {
        await loadStats()
        await loadLogs()
    }
}
