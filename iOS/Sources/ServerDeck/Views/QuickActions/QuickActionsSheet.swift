import SwiftUI

public struct QuickActionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var appState: AppState

    @State private var isExecutingAction = false
    @State private var actionMessage: String?
    @State private var isActionSuccess = true

    // Confirmation dialog states
    @State private var showConfirmReboot = false
    @State private var showConfirmShutdown = false
    @State private var showConfirmPrune = false
    @State private var showConfirmRestartUnhealthy = false
    @State private var showDiagnosticsSheet = false
    @State private var showTerminalSheet = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // Status Alert Banner if action finished
                    if let actionMessage = actionMessage {
                        HStack(spacing: 8) {
                            Image(systemName: isActionSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(isActionSuccess ? Theme.success : Theme.danger)
                            Text(actionMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background((isActionSuccess ? Theme.success : Theme.danger).opacity(0.12))
                        .cornerRadius(12)
                    }

                    // 1. Host Control Section (Reboot & Shutdown)
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "power.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(Theme.danger)

                                Text("GESTIONE HOST PC (SRV-01)")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            // Action: Reboot Host
                            Button {
                                showConfirmReboot = true
                                HapticManager.warning()
                            } label: {
                                ActionRow(
                                    title: "Riavvia Server Host",
                                    subtitle: "Esegue il reboot pulito di srv-01 via systemd. Servizi riavviati.",
                                    icon: "arrow.counterclockwise.circle.fill",
                                    iconColor: .orange
                                )
                            }
                            .buttonStyle(.plain)

                            // Action: Shutdown Host
                            Button {
                                showConfirmShutdown = true
                                HapticManager.heavy()
                            } label: {
                                ActionRow(
                                    title: "Spegni Server Host",
                                    subtitle: "Esegue il power-off di srv-01. Richiede accensione manuale.",
                                    icon: "power.circle.fill",
                                    iconColor: Theme.danger
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 2. Docker & Maintenance Section
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)

                                Text("MANUTENZIONE & SHORTCUTS")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            // Action: Docker Prune
                            Button {
                                showConfirmPrune = true
                                HapticManager.light()
                            } label: {
                                ActionRow(
                                    title: "Docker System Prune",
                                    subtitle: "Pulisce container fermi, immagini orfane e cache per liberare disco.",
                                    icon: "trash.circle.fill",
                                    iconColor: .cyan
                                )
                            }
                            .buttonStyle(.plain)

                            // Action: Restart Unhealthy Containers
                            Button {
                                showConfirmRestartUnhealthy = true
                                HapticManager.light()
                            } label: {
                                ActionRow(
                                    title: "Riavvia Container Non Sani",
                                    subtitle: "Individua e riavvia i container bloccati, crashati o non sani.",
                                    icon: "arrow.triangle.2.circlepath.circle.fill",
                                    iconColor: Theme.warning
                                )
                            }
                            .buttonStyle(.plain)

                            // Action: Interactive Shell Terminal
                            Button {
                                showTerminalSheet = true
                                HapticManager.light()
                            } label: {
                                ActionRow(
                                    title: "Terminale Shell Host (srv-01)",
                                    subtitle: "Esegui comandi shell interattivi direttamente sul sistema Debian.",
                                    icon: "terminal.fill",
                                    iconColor: .green
                                )
                            }
                            .buttonStyle(.plain)

                            // Action: System Diagnostics Console
                            Button {
                                showDiagnosticsSheet = true
                                HapticManager.light()
                            } label: {
                                ActionRow(
                                    title: "Diagnostica & Telemetria Host",
                                    subtitle: "Ispeziona kernel, swap, storage e log di sistema.",
                                    icon: "chart.bar.doc.horizontal.fill",
                                    iconColor: .cyan
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 3. Fallback Web Portainer
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.accentColor)

                                Text("FALLBACK PORTAINER")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            Button {
                                openPortainerFallback()
                            } label: {
                                ActionRow(
                                    title: "Apri Portainer Web",
                                    subtitle: "Accesso diretto alla dashboard Portainer originale per operazioni avanzate.",
                                    icon: "arrow.up.forward.app.fill",
                                    iconColor: .accentColor
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Azioni Rapide & Host")
            .navigationTitleModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDiagnosticsSheet) {
                SystemDiagnosticsSheet(apiClient: appState.apiClient)
            }
            .sheet(isPresented: $showTerminalSheet) {
                HostTerminalSheet(apiClient: appState.apiClient)
            }
            // Double-Confirmation Dialogs for Safety
            .confirmationDialog(
                "Riavvia Host srv-01",
                isPresented: $showConfirmReboot,
                titleVisibility: .visible
            ) {
                Button("Riavvia srv-01", role: .destructive) {
                    executeReboot()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Sei sicuro di voler riavviare il server srv-01? Tutti i container verranno interrotti e riavviati automaticamente.")
            }
            .confirmationDialog(
                "ATTENZIONE: Spegni Host srv-01",
                isPresented: $showConfirmShutdown,
                titleVisibility: .visible
            ) {
                Button("Spegni Definitivamente srv-01", role: .destructive) {
                    executeShutdown()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Spegnendo srv-01, il server si arresterà completamente e perderai l'accesso remoto finché non verrà riacceso fisicamente dal pulsante del PC!")
            }
            .confirmationDialog(
                "Esegui Docker System Prune",
                isPresented: $showConfirmPrune,
                titleVisibility: .visible
            ) {
                Button("Pulisci Immagini e Cache", role: .destructive) {
                    executePrune()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Verranno rimossi i container terminati e le immagini orfane non associate ad alcun container attivo per liberare spazio su disco.")
            }
            .confirmationDialog(
                "Riavvia Container Non Sani",
                isPresented: $showConfirmRestartUnhealthy,
                titleVisibility: .visible
            ) {
                Button("Riavvia Adesso", role: .destructive) {
                    executeRestartUnhealthy()
                }
                Button("Annulla", role: .cancel) {}
            } message: {
                Text("Verrà inviato un comando di restart a tutti i container in stato 'unhealthy' o 'exited'.")
            }
            .overlay {
                if isExecutingAction {
                    ProgressView("Esecuzione comando...")
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func executeReboot() {
        isExecutingAction = true
        HapticManager.heavy()
        Task {
            do {
                let resp = try await appState.apiClient.rebootHost()
                actionMessage = "✓ \(resp.message)"
                isActionSuccess = true
                HapticManager.success()
            } catch {
                actionMessage = "Errore: \(error.localizedDescription)"
                isActionSuccess = false
                HapticManager.error()
            }
            isExecutingAction = false
        }
    }

    private func executeShutdown() {
        isExecutingAction = true
        HapticManager.heavy()
        Task {
            do {
                let resp = try await appState.apiClient.shutdownHost()
                actionMessage = "✓ \(resp.message)"
                isActionSuccess = true
                HapticManager.success()
            } catch {
                actionMessage = "Errore: \(error.localizedDescription)"
                isActionSuccess = false
                HapticManager.error()
            }
            isExecutingAction = false
        }
    }

    private func executePrune() {
        isExecutingAction = true
        HapticManager.light()
        Task {
            do {
                let report = try await appState.apiClient.pruneSystem()
                actionMessage = "✓ Spazio liberato: \(report.formattedReclaimed) (\(report.containersDeleted) container, \(report.imagesDeleted) immagini rimosse)"
                isActionSuccess = true
                HapticManager.success()
            } catch {
                actionMessage = "Errore Prune: \(error.localizedDescription)"
                isActionSuccess = false
                HapticManager.error()
            }
            isExecutingAction = false
        }
    }

    private func executeRestartUnhealthy() {
        isExecutingAction = true
        HapticManager.light()
        Task {
            do {
                let resp = try await appState.apiClient.restartUnhealthyContainers()
                actionMessage = "✓ \(resp.message ?? "Riavviati container non sani")"
                isActionSuccess = true
                HapticManager.success()
            } catch {
                actionMessage = "Errore restart: \(error.localizedDescription)"
                isActionSuccess = false
                HapticManager.error()
            }
            isExecutingAction = false
        }
    }

    private func openPortainerFallback() {
        HapticManager.light()
        var targetURL = "https://srv-01:9443"
        if let tsURL = appState.config.cleanTailscaleURL {
            targetURL = "https://\(tsURL.host ?? "100.75.107.88"):9443"
        }
        if let url = URL(string: targetURL) {
            openURL(url)
        }
    }
}

private struct ActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundColor(iconColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(12)
    }
}
