import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ServerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    private let existingServer: ServerConfig?

    @State private var name: String
    @State private var localURL: String
    @State private var tailscaleURL: String
    @State private var token: String
    @State private var allowInsecureSSL: Bool
    @State private var isTokenVisible: Bool = false

    // Testing state
    @State private var isTesting: Bool = false
    @State private var testResult: String?
    @State private var testSuccess: Bool?

    public init(server: ServerConfig? = nil) {
        self.existingServer = server
        _name = State(initialValue: server?.name ?? "")
        _localURL = State(initialValue: server?.localURL ?? "http://")
        _tailscaleURL = State(initialValue: server?.tailscaleURL ?? "http://")
        _token = State(initialValue: server?.token ?? "")
        _allowInsecureSSL = State(initialValue: server?.allowInsecureSSL ?? true)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Identità Server") {
                    TextField("Nome (es. srv-01, Mini PC, VPS)", text: $name)
                        .autocorrectionDisabled()
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("URL Rete Locale (LAN)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Priorità 1 (Wi-Fi)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }

                        TextField("http://10.0.0.99:8080", text: $localURL)
                            .font(.system(size: 14, design: .monospaced))
                            .autocorrectionDisabled()
                            #if canImport(UIKit)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("URL Remoto (Tailscale)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Priorità 2 (VPN)")
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }

                        TextField("http://100.75.107.88:8080", text: $tailscaleURL)
                            .font(.system(size: 14, design: .monospaced))
                            .autocorrectionDisabled()
                            #if canImport(UIKit)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            #endif
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("API Token")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Button {
                                isTokenVisible.toggle()
                                HapticManager.selection()
                            } label: {
                                Image(systemName: isTokenVisible ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }

                        if isTokenVisible {
                            TextField("Token segreto", text: $token)
                                .font(.system(size: 14, design: .monospaced))
                                .autocorrectionDisabled()
                                #if canImport(UIKit)
                                .textInputAutocapitalization(.never)
                                #endif
                        } else {
                            SecureField("Token segreto", text: $token)
                                .font(.system(size: 14, design: .monospaced))
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Connessione di Rete")
                } footer: {
                    Text("L'app verificherà prima l'IP locale e passerà automaticamente all'indirizzo Tailscale quando sei fuori casa.")
                }

                Section {
                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }
                            Text(isTesting ? "Test in corso..." : "Verifica Connessione")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isTesting || (localURL.isEmpty && tailscaleURL.isEmpty))

                    if let result = testResult {
                        HStack(spacing: 8) {
                            Image(systemName: (testSuccess == true) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor((testSuccess == true) ? Theme.success : Theme.danger)

                            Text(result)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor((testSuccess == true) ? Theme.success : Theme.danger)
                        }
                    }
                }
            }
            .navigationTitle(existingServer == nil ? "Nuovo Server" : "Modifica Server")
            .navigationTitleModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || (localURL.isEmpty && tailscaleURL.isEmpty))
                }
            }
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil
        testSuccess = nil
        HapticManager.light()

        let testConfig = ServerConfig(
            id: existingServer?.id ?? UUID(),
            name: name,
            localURL: localURL.trimmingCharacters(in: .whitespaces),
            tailscaleURL: tailscaleURL.trimmingCharacters(in: .whitespaces),
            token: token.trimmingCharacters(in: .whitespaces),
            allowInsecureSSL: allowInsecureSSL
        )

        let client = APIClient(config: testConfig)

        Task {
            do {
                let res = try await client.testConnection()
                testSuccess = true
                testResult = "Connessione riuscita via \(res.modeDescription)! Latenza: \(res.latencyMs) ms"
                HapticManager.success()
            } catch {
                testSuccess = false
                testResult = "Test fallito: \(error.localizedDescription)"
                HapticManager.error()
            }
            isTesting = false
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedLocal = localURL.trimmingCharacters(in: .whitespaces)
        let trimmedTS = tailscaleURL.trimmingCharacters(in: .whitespaces)
        let trimmedToken = token.trimmingCharacters(in: .whitespaces)

        if let existing = existingServer {
            var updated = existing
            updated.name = trimmedName
            updated.localURL = trimmedLocal
            updated.tailscaleURL = trimmedTS
            updated.token = trimmedToken
            updated.allowInsecureSSL = allowInsecureSSL
            appState.updateConfig(updated)
        } else {
            let newServer = ServerConfig(
                id: UUID(),
                name: trimmedName,
                localURL: trimmedLocal,
                tailscaleURL: trimmedTS,
                token: trimmedToken,
                allowInsecureSSL: allowInsecureSSL
            )
            appState.addServer(newServer)
        }

        HapticManager.success()
        dismiss()
    }
}
