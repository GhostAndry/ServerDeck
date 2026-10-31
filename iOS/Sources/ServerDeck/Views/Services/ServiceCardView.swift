import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public struct ServiceCardView: View {
    let service: ServiceItem
    var onOpen: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    public init(
        service: ServiceItem,
        onOpen: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.service = service
        self.onOpen = onOpen
        self.onDelete = onDelete
    }

    private var statusColor: Color {
        Theme.colorForServiceStatus(service.status)
    }

    public var body: some View {
        Button {
            onOpen?()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    // Service Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 44, height: 44)

                        Image(systemName: service.icon)
                            .font(.system(size: 20))
                            .foregroundColor(.accentColor)
                    }

                    Spacer()

                    // Online / Offline Status Dot + Latency
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 7, height: 7)

                            Text(service.status.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(statusColor)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.12))
                        .cornerRadius(6)

                        if service.isOnline {
                            Text("\(service.responseTimeMs) ms")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Service Name & Category & Auto badge
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(service.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if service.isAutoDiscovered {
                            Text("AUTO")
                                .font(.system(size: 9, weight: .heavy))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    Text(service.category)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }

                // URL preview
                HStack {
                    Text(service.url)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onOpen?()
            } label: {
                Label("Apri nel Browser", systemImage: "safari")
            }

            Button {
                #if canImport(UIKit)
                UIPasteboard.general.string = service.url
                #endif
                HapticManager.success()
            } label: {
                Label("Copia URL", systemImage: "doc.on.doc")
            }

            if onDelete != nil {
                Divider()
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("Elimina Servizio", systemImage: "trash")
                }
            }
        }
    }
}
