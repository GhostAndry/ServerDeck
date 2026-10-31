import SwiftUI

public struct DiskMetricCard: View {
    let disks: [DiskStats]

    public init(disks: [DiskStats]) {
        self.disks = disks
    }

    private var hasAnyWarning: Bool {
        disks.contains(where: { $0.isWarning })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "internaldrive")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(hasAnyWarning ? Theme.warning : .accentColor)

                    Text("STORAGE & VOLUMES")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if hasAnyWarning {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                        Text("High Usage")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Theme.warning)
                }
            }

            VStack(spacing: 10) {
                if disks.isEmpty {
                    Text("No disk data available")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(disks) { disk in
                        DiskUsageBar(disk: disk)
                    }
                }
            }
        }
    }
}
