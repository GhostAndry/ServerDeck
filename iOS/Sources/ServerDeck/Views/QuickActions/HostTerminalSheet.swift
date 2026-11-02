import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct HostTerminalSheet: View {
    @Environment(\.dismiss) private var dismiss
    let apiClient: APIClient

    @State private var commandInput: String = ""
    @State private var history: [ExecResult] = []
    @State private var isExecuting: Bool = false
    @State private var errorMessage: String?

    private let shortcutCommands = [
        "uptime",
        "free -h",
        "df -h",
        "docker ps",
        "ip -br a",
        "cat /etc/os-release",
        "systemctl is-active docker"
    ]

    public init(apiClient: APIClient) {
        self.apiClient = apiClient
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 1. Quick Shortcut Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(shortcutCommands, id: \.self) { cmd in
                            Button {
                                HapticManager.selection()
                                executeCommand(cmd)
                            } label: {
                                Text(cmd)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.primary.opacity(0.06))
                                    .foregroundColor(.primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                Divider()

                // 2. Terminal Screen Output
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            if history.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("ServerDeck Host Terminal v1.0")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(.green)

                                    Text("Connesso direttamente all'ambiente Debian di srv-01 via nsenter.")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.green.opacity(0.8))

                                    Text("Tocca uno shortcut in alto o digita un comando sotto.")
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(.secondary)
                                }
                                .padding(12)
                            }

                            ForEach(Array(history.enumerated()), id: \.offset) { index, item in
                                VStack(alignment: .leading, spacing: 6) {
                                    // Command Header
                                    HStack(spacing: 6) {
                                        Text("andrea@srv-01:~$")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundColor(.cyan)

                                        Text(item.command)
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundColor(.white)

                                        Spacer()

                                        Text("\(item.durationMs)ms")
                                            .font(.system(size: 10, design: .monospaced))
                                            .foregroundColor(.secondary)

                                        Text(item.exitCode == 0 ? "✓" : "exit \(item.exitCode)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(item.exitCode == 0 ? .green : .red)
                                    }

                                    // Stdout Output
                                    if !item.stdout.isEmpty {
                                        Text(item.stdout)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.green)
                                            .textSelection(.enabled)
                                    }

                                    // Stderr Output
                                    if !item.stderr.isEmpty {
                                        Text(item.stderr)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(.red)
                                            .textSelection(.enabled)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black.opacity(0.85))
                                .cornerRadius(10)
                                .id(index)
                            }

                            if let errorMessage = errorMessage {
                                Text("Errore esecuzione: \(errorMessage)")
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.red)
                                    .padding(8)
                            }
                        }
                        .padding(14)
                    }
                    .background(Color(red: 0.05, green: 0.07, blue: 0.10))
                    .onChange(of: history.count) { _ in
                        if let lastIndex = history.indices.last {
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                // 3. Command Input Bar
                HStack(spacing: 10) {
                    Text("$")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.cyan)

                    TextField("Comando shell (es. uptime, sensors)", text: $commandInput)
                        .font(.system(size: 14, design: .monospaced))
                        .autocorrectionDisabled(true)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.asciiCapable)
                        #endif
                        .onSubmit {
                            executeCommand(commandInput)
                        }

                    Button {
                        executeCommand(commandInput)
                    } label: {
                        if isExecuting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.cyan)
                        }
                    }
                    .disabled(commandInput.trimmingCharacters(in: .whitespaces).isEmpty || isExecuting)
                }
                .padding(12)
                .background(Color.primary.opacity(0.04))
            }
            .navigationTitle("Terminale Host (srv-01)")
            .navigationTitleModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        history.removeAll()
                        HapticManager.light()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                    }
                }
            }
        }
    }

    private func executeCommand(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !isExecuting else { return }

        // Clear input line immediately
        commandInput = ""

        isExecuting = true
        errorMessage = nil
        HapticManager.light()

        Task {
            do {
                let res = try await apiClient.executeHostCommand(trimmed)
                history.append(res)
                HapticManager.success()
            } catch {
                errorMessage = error.localizedDescription
                HapticManager.error()
            }
            isExecuting = false
        }
    }
}
