import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SettingsViewModel
    @State private var isTokenVisible: Bool = false
    @State private var showAddServerSheet: Bool = false
    @State private var editingServer: ServerConfig? = nil
    @State private var serverToDelete: ServerConfig? = nil

    public init(config: ServerConfig) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(config: config))
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Multi-Server Hub
                Section("I Miei Server Homelab") {
                    ForEach(appState.servers) { s in
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .font(.system(size: 18))
                                .foregroundColor(s.id == appState.activeServerId ? .accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(s.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.primary)

                                    if s.id == appState.activeServerId {
                                        Text("ATTIVO")
                                            .font(.system(size: 9, weight: .heavy))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor.opacity(0.15))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(4)
                                    }
                                }

                                Text(s.localURL.isEmpty ? s.tailscaleURL : s.localURL)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Button {
                                editingServer = s
                                HapticManager.light()
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.borderless)

                            if s.id == appState.activeServerId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 18))
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if s.id != appState.activeServerId {
                                appState.switchServer(to: s.id)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if appState.servers.count > 1 {
                                Button(role: .destructive) {
                                    serverToDelete = s
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                    }

                    Button {
                        showAddServerSheet = true
                        HapticManager.light()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Aggiungi Nuovo Server")
                                .fontWeight(.medium)
                        }
                    }
                }

                // Section 2: Active Server Connection Details
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nome del Server")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)

                        TextField("srv-01", text: $viewModel.name)
                            .font(.system(size: 14))
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)

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

                        TextField("http://10.0.0.99:8080", text: $viewModel.localURL)
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

                        TextField("http://100.75.107.88:8080", text: $viewModel.tailscaleURL)
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
                            Text("API Token (Bearer)")
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
                            TextField("Token segreto", text: $viewModel.token)
                                .font(.system(size: 14, design: .monospaced))
                                .autocorrectionDisabled()
                                #if canImport(UIKit)
                                .textInputAutocapitalization(.never)
                                #endif
                        } else {
                            SecureField("Token segreto", text: $viewModel.token)
                                .font(.system(size: 14, design: .monospaced))
                        }
                    }
                    .padding(.vertical, 4)

                    // Test Connection Button
                    Button {
                        Task { await viewModel.testConnection() }
                    } label: {
                        HStack {
                            if viewModel.isTestingConnection {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                            }

                            Text(viewModel.isTestingConnection ? "Verifica in corso..." : "Test Connessione Server")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isTestingConnection)

                    if let message = viewModel.testStatusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: (viewModel.testSucceeded == true) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor((viewModel.testSucceeded == true) ? Theme.success : Theme.danger)

                            Text(message)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor((viewModel.testSucceeded == true) ? Theme.success : Theme.danger)
                        }
                    }

                    // Save Button
                    Button {
                        viewModel.save(appState: appState)
                    } label: {
                        HStack {
                            Spacer()
                            Text(viewModel.hasSavedSuccessfully ? "Salvato ✓" : "Salva Modifiche")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(viewModel.hasSavedSuccessfully ? Theme.success : .accentColor)
                } header: {
                    Text("Configurazione Server: \(appState.config.name)")
                } footer: {
                    Text("I token sono archiviati in modo sicuro nel Secure Enclave iOS via Keychain.")
                }

                // Section 3: Security & Network
                Section("Sicurezza & Certificati") {
                    Toggle("Consenti SSL Self-Signed / Tailscale", isOn: $viewModel.allowInsecureSSL)

                    if viewModel.biometricType != .none {
                        Toggle("Richiedi \(viewModel.biometricType.title)", isOn: $viewModel.requireBiometrics)
                    }

                    NavigationLink {
                        TailscaleGuideView()
                    } label: {
                        Label("Guida Configurazione Tailscale", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    }
                }

                // Section 4: Diagnostics
                Section("Diagnostica & Modalità Demo") {
                    Toggle("Modalità Demo (Offline Mock)", isOn: $viewModel.useMockData)
                        .onChange(of: viewModel.useMockData) {
                            viewModel.save(appState: appState)
                        }
                }

                // Section 5: About
                Section("Informazioni") {
                    HStack {
                        Text("Versione App")
                        Spacer()
                        Text("1.0.0 (Open Source)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Repository GitHub")
                        Spacer()
                        Link("GhostAndry/ServerDeck", destination: URL(string: "https://github.com/GhostAndry/ServerDeck")!)
                            .font(.system(size: 13, weight: .medium))
                    }
                }
            }
            .navigationTitle("Impostazioni")
            .navigationTitleModeLarge()
            .sheet(isPresented: $showAddServerSheet) {
                ServerEditorSheet()
            }
            .sheet(item: $editingServer) { s in
                ServerEditorSheet(server: s)
            }
            .confirmationDialog(
                "Elimina Server",
                isPresented: Binding(
                    get: { serverToDelete != nil },
                    set: { if !$0 { serverToDelete = nil } }
                ),
                presenting: serverToDelete
            ) { s in
                Button("Elimina \(s.name)", role: .destructive) {
                    appState.deleteServer(id: s.id)
                    HapticManager.success()
                }
                Button("Annulla", role: .cancel) {}
            } message: { s in
                Text("Vuoi davvero rimuovere \(s.name) dall'elenco dei server?")
            }
            .onChange(of: appState.activeServerId) {
                viewModel.syncWithConfig(appState.config)
            }
        }
    }
}
