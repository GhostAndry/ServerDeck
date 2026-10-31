import SwiftUI

public struct ContainerSummaryBadgesView: View {
    let summary: ContainersSummary
    var onSelect: ((ContainerFilterState) -> Void)? = nil

    public init(summary: ContainersSummary, onSelect: ((ContainerFilterState) -> Void)? = nil) {
        self.summary = summary
        self.onSelect = onSelect
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)

                Text("CONTAINER STATUS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                summaryBadge(
                    title: "Total",
                    count: summary.total,
                    color: Color.primary,
                    filter: .all
                )

                summaryBadge(
                    title: "Running",
                    count: summary.running,
                    color: Theme.success,
                    filter: .running
                )

                summaryBadge(
                    title: "Stopped",
                    count: summary.stopped,
                    color: Color.secondary,
                    filter: .stopped
                )

                summaryBadge(
                    title: "Unhealthy",
                    count: summary.unhealthy,
                    color: summary.unhealthy > 0 ? Theme.danger : Color.secondary.opacity(0.6),
                    filter: .unhealthy
                )
            }
        }
    }

    private func summaryBadge(title: String, count: Int, color: Color, filter: ContainerFilterState) -> some View {
        Button {
            onSelect?(filter)
        } label: {
            VStack(spacing: 4) {
                Text("\(count)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(color)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(color.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}
