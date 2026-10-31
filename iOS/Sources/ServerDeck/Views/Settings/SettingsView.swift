import SwiftUI

public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: SettingsViewModel
    @State private var isTokenVisible: Bool = false

    public init(config: ServerConfig) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(config: config))
    }

    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Server Connection
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
                            TextField("Enter API Token", text: $viewModel.token)
                                .font(.system(size: 14, design: .monospaced))
                                .autocorrectionDisabled()
                                #if canImport(UIKit)
                                .textInputAutocapitalization(.never)
                                #endif
                        } else {
                            SecureField("Enter API Token", text: $viewModel.token)
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

                            Text(viewModel.isTestingConnection ? "Testing..." : "Test Connection")
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
                            Text(viewModel.hasSavedSuccessfully ? "Saved ✓" : "Save Changes")
                                .fontWeight(.bold)
                            Spacer()
                        }
                    }
                    .foregroundColor(viewModel.hasSavedSuccessfully ? Theme.success : .accentColor)
                } header: {
                    Text("Connection Configuration")
                } footer: {
                    Text("Tokens are securely stored in the iOS Secure Enclave Keychain.")
                }

                // Section 2: Security & Network
                Section("Security & Network") {
                    Toggle("Allow Self-Signed / Tailscale SSL", isOn: $viewModel.allowInsecureSSL)

                    if viewModel.biometricType != .none {
                        Toggle("Require \(viewModel.biometricType.title)", isOn: $viewModel.requireBiometrics)
                    }

                    NavigationLink {
                        TailscaleGuideView()
                    } label: {
                        Label("Tailscale Setup Guide", systemImage: "point.3.filled.connected.trianglepath.dotted")
                    }
                }

                // Section 3: Diagnostics
                Section("Diagnostics & Testing") {
                    Toggle("Use Demo Mode (Offline Mock)", isOn: $viewModel.useMockData)
                        .onChange(of: viewModel.useMockData) {
                            viewModel.save(appState: appState)
                        }
                }

                // Section 4: About
                Section("About") {
                    HStack {
                        Text("App Version")
                        Spacer()
                        Text("1.0.0 (Build 1)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Backend")
                        Spacer()
                        Text("ServerDeck Go Agent")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Network Architecture")
                        Spacer()
                        Text("Tailscale Private Mesh")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationTitleModeLarge()
        }
    }
}
