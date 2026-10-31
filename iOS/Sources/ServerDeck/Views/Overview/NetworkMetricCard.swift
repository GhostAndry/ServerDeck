import SwiftUI

public struct NetworkMetricCard: View {
    let rxRate: String
    let txRate: String

    public init(rxRate: String, txRate: String) {
        self.rxRate = rxRate
        self.txRate = txRate
    }

    public var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.accentColor)

                    Text("NETWORK THROUGHPUT")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    // Download
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Theme.success)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("DOWNLOAD")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)

                            Text(rxRate)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                        .frame(height: 36)

                    // Upload
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("UPLOAD")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)

                            Text(txRate)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
