import SwiftUI

public struct TailscaleGuideView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "point.3.filled.connected.trianglepath.dotted")
                            .font(.system(size: 24))
                            .foregroundColor(.accentColor)

                        Text("Tailscale Private Mesh")
                            .font(.system(size: 20, weight: .bold))
                    }

                    Text("ServerDeck connects securely to your Debian server over Tailscale without exposing any open ports to the public internet.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 6)

                // Step 1: Debian Setup
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("1")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())

                            Text("Install Tailscale on srv-01")
                                .font(.system(size: 15, weight: .bold))
                        }

                        Text("Run the official installation script on Debian:")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Text("curl -fsSL https://tailscale.com/install.sh | sh\nsudo tailscale up")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                    }
                }

                // Step 2: iOS Setup
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("2")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())

                            Text("Install Tailscale on iPhone")
                                .font(.system(size: 15, weight: .bold))
                        }

                        Text("Download Tailscale from the iOS App Store and sign into the same account as your server. Toggle the VPN switch to ON.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                // Step 3: Configure ServerDeck
                CardView {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("3")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Circle())

                            Text("Connect in ServerDeck Settings")
                                .font(.system(size: 15, weight: .bold))
                        }

                        Text("Use your server's Tailscale MagicDNS name or 100.x.y.z IP:")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Text("http://srv-01:8080\n# or\nhttp://100.x.y.z:8080")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.primary.opacity(0.06))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle("Tailscale Setup")
        .navigationTitleModeInline()
    }
}
