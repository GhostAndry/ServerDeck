import SwiftUI

public struct DiskUsageBar: View {
    let disk: DiskStats

    public init(disk: DiskStats) {
        self.disk = disk
    }

    private var progressColor: Color {
        Theme.colorForUsage(disk.usagePercent)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: disk.mountPoint == "/" ? "internaldrive.fill" : "externaldrive.fill")
                        .foregroundColor(progressColor)
                        .font(.system(size: 14))

                    Text(disk.mountPoint)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)

                    if disk.isWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(disk.isCritical ? Theme.danger : Theme.warning)
                            .font(.system(size: 12))
                    }
                }

                Spacer()

                Text(Formatters.formatPercent(disk.usagePercent, decimals: 0))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(progressColor)
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 8)

                    Capsule()
                        .fill(progressColor)
                        .frame(
                            width: max(0, min(geo.size.width * CGFloat(disk.usagePercent / 100.0), geo.size.width)),
                            height: 8
                        )
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: disk.usagePercent)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Formatters.formatBytes(disk.usedBytes)) used of \(Formatters.formatBytes(disk.totalBytes))")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.secondary)

                Spacer()

                Text(disk.filesystem)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary.opacity(0.8))
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            disk.isCritical ? Theme.danger.opacity(0.4) :
                            (disk.isWarning ? Theme.warning.opacity(0.3) : Color.primary.opacity(0.06)),
                            lineWidth: disk.isWarning ? 1.5 : 1.0
                        )
                }
        }
    }
}
