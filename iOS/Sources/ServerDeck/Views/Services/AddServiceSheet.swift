import SwiftUI

public struct AddServiceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ServicesViewModel

    @State private var name: String = ""
    @State private var url: String = "http://srv-01:"
    @State private var category: String = "Monitoring"
    @State private var selectedIcon: String = "chart.xyaxis.line"
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?

    private let availableCategories = [
        "Monitoring", "Management", "Media", "Apps", "AI", "Networking", "Database", "Custom"
    ]

    private let availableIcons = [
        "chart.xyaxis.line", "shippingbox.fill", "network", "key.fill",
        "play.tv.fill", "shield.fill", "bubble.left.and.bubble.right.fill",
        "cylinder.split.1x2.fill", "bolt.fill", "server.rack", "arrow.down.circle.fill", "app.fill"
    ]

    public init(viewModel: ServicesViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Dati Servizio") {
                    TextField("Nome (es. Beszel, Grafana)", text: $name)
                        .autocorrectionDisabled()

                    TextField("URL (es. http://srv-01:8090)", text: $url)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                }

                Section("Categoria") {
                    Picker("Categoria", selection: $category) {
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }

                Section("Icona") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                                HapticManager.selection()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selectedIcon == icon ? Color.accentColor : Color.primary.opacity(0.06))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(selectedIcon == icon ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Nuovo Servizio")
            .navigationTitleModeInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        submit()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || url.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        HapticManager.light()

        Task {
            let success = await viewModel.addService(
                name: name.trimmingCharacters(in: .whitespaces),
                url: url.trimmingCharacters(in: .whitespaces),
                icon: selectedIcon,
                category: category
            )
            isSubmitting = false
            if success {
                HapticManager.success()
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage ?? "Impossibile aggiungere il servizio"
                HapticManager.error()
            }
        }
    }
}
