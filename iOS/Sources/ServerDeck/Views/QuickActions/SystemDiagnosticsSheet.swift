import SwiftUI

public struct SystemDiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let apiClient: APIClient

    @State private var report: DiagnosticReport?
    @State private var isLoading = true
    @State private var errorMessage: String?

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let report = report {
                        // 1. Host Summary
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "server.rack")
                                        .foregroundColor(.accentColor)
                                    Text("INFORMAZIONI HOST")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                LabeledRow(label: "Hostname", value: report.hostname)
                                LabeledRow(label: "Piattaforma / OS", value: report.platform)
                                LabeledRow(label: "Kernel", value: report.kernel)
                                LabeledRow(label: "Architettura", value: report.arch)
                                LabeledRow(label: "Uptime", value: Formatters.formatUptime(report.uptimeSeconds))
                            }
                        }

                        // 2. Memory & Swap Breakdown
                        CardView {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "memorychip")
                                        .foregroundColor(.blue)
                                    Text("MEMORIA RAM & SWAP")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }

                                Divider()

                                LabeledRow(label: "RAM Totale", value: Formatters.formatBytes(report.memoryTotal))
                                LabeledRow(label: "RAM Usata", value: Formatters.formatBytes(report.memoryUsed))
                                LabeledRow(label: "RAM Libera", value: Formatters.formatBytes(report.memoryFree))
                                if report.swapTotal > 0 {
                                    LabeledRow(label: "Swap Totale", value: Formatters.formatBytes(report.swapTotal))
                                    LabeledRow(label: "Swap Usata", value: Formatters.formatBytes(report.swapUsed))
                                }
                            }
                        }

                        // 3. Storage Details
                        if let disks = report.storageDetails, !disks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "internaldrive")
                                        .foregroundColor(.cyan)
                                    Text("PARTIZIONI DISCO")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }

                                ForEach(disks) { d in
                                    DiskUsageBar(disk: DiskStats(
                                        mountPoint: d.mountPoint,
                                        filesystem: d.filesystem,
                                        totalBytes: d.totalBytes,
                                        usedBytes: d.usedBytes,
                                        freeBytes: max(0, d.totalBytes - d.usedBytes),
                                        usagePercent: d.usagePercent
                                    ))
                                }
                            }
                        }

                        // 4. Diagnostic Terminal Log Console
                        if let logs = report.diagnosticLogs, !logs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "terminal.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.green)
                                    Text("CONSOLE LOGS DI SISTEMA")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.secondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(Array(logs.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.green)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.85))
                                .cornerRadius(12)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                                }
                            }
                        }
                    } else if let errorMessage = errorMessage {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.danger)
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(32)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Diagnostica Server")
            .navigationTitleModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .task {
                await loadData()
            }
            .overlay {
                if isLoading && report == nil {
                    ProgressView("Caricamento diagnostica...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            self.report = try await apiClient.fetchDiagnostics()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
