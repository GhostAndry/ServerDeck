import SwiftUI

public struct StatGaugeView: View {
    let title: String
    let percent: Double
    let detailText: String
    let icon: String
    var accentColor: Color?

    public init(
        title: String,
        percent: Double,
        detailText: String,
        icon: String,
        accentColor: Color? = nil
    ) {
        self.title = title
        self.percent = percent
        self.detailText = detailText
        self.icon = icon
        self.accentColor = accentColor
    }

    private var activeColor: Color {
        accentColor ?? Theme.colorForUsage(percent)
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background Track
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 9)

                // Progress Track
                Circle()
                    .trim(from: 0.0, to: min(max(CGFloat(percent) / 100.0, 0.0), 1.0))
                    .stroke(
                        activeColor,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: percent)

                // Center readout
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(activeColor)

                    Text(Formatters.formatPercent(percent, decimals: 0))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 86, height: 86)
            .padding(.top, 4)

            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)

                Text(detailText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                }
        }
    }
}
