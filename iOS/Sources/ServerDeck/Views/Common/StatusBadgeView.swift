import SwiftUI

public struct StatusBadgeView: View {
    let title: String
    let color: Color
    var isPulsing: Bool = false

    @State private var pulse: Bool = false

    public init(title: String, color: Color, isPulsing: Bool = false) {
        self.title = title
        self.color = color
        self.isPulsing = isPulsing
    }

    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
                .scaleEffect(isPulsing && pulse ? 1.3 : 1.0)
                .opacity(isPulsing && pulse ? 0.7 : 1.0)
                .animation(
                    isPulsing ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                    value: pulse
                )

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background {
            Capsule()
                .fill(color.opacity(0.12))
        }
        .onAppear {
            if isPulsing {
                pulse = true
            }
        }
    }
}
