import SwiftUI

public struct ConnectionStatusBanner: View {
    let state: WebSocketState
    let isMockData: Bool

    public init(state: WebSocketState, isMockData: Bool) {
        self.state = state
        self.isMockData = isMockData
    }

    public var body: some View {
        if isMockData {
            HStack(spacing: 6) {
                Image(systemName: "flask.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Demo Mode (Offline Mock Data)")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.orange)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.15))
        } else if !state.isConnected {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.7)
                Text(state.statusDescription)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(Color.secondary.opacity(0.12))
        }
    }
}
