# 📱 ServerDeck — Native iOS Client (SwiftUI)

ServerDeck is a high-performance, native iOS client engineered for managing and monitoring your Debian Docker homelab (`srv-01`) directly from your iPhone over a secure Tailscale private network.

Built with **Swift 6** and **SwiftUI (iOS 17+)**, ServerDeck combines real-time system metrics, container orchestration (start, stop, restart, live log streaming), homelab service status probing, and emergency quick actions in a dark/light native interface.

---

## 🌟 Key Features

1. **Host Telemetry & Monitoring (Overview Tab)**:
   - Live CPU usage percentage, core count, model, and thermal sensor readout.
   - Real-time RAM consumption gauge with used vs. total bytes.
   - Storage volume cards with automated **80% warning / 90% critical** threshold highlights for `/` and `/mnt/DATA`.
   - Dual-directional live network throughput meter (RX / TX rate).
   - Tappable container state summary badges (Total, Running, Stopped, Unhealthy).

2. **Docker Container Management (Containers Tab)**:
   - Real-time search across container names, IDs, image tags, and Docker Compose stacks.
   - Compose stack filter chips (`All`, `OpenWebUI`, `Media`, `Core`, `Networking`, etc.).
   - Status filters (`All`, `Running`, `Stopped`, `Unhealthy`).
   - Swipe actions and context menus for instant Start, Stop, and Restart with confirmation dialogs.
   - **Terminal-Style Live Log Stream**: Monospaced font, dark GitHub/terminal aesthetic, real-time search filter, timestamp toggle, auto-scroll to bottom, and one-tap clipboard copy.

3. **Homelab Services Hub (Services Tab)**:
   - Visual dashboard for self-hosted apps: OpenWebUI, Portainer, qBittorrent, Jellyfin, Radarr, Sonarr, AdGuard Home, etc.
   - HTTP health probing with live response latency (ms) and status indicators.
   - Direct tap to open services in Safari.

4. **Emergency Quick Actions**:
   - One-tap "Restart Failing Containers" to automatically revive stopped or unhealthy services.
   - Direct Portainer web dashboard fallback.
   - Instant server health status snapshot.

5. **Security & Offline Demo Mode**:
   - Apple **Keychain (Secure Enclave)** storage for API tokens and server endpoints.
   - Optional **Face ID / Touch ID / Optic ID** biometric app lock.
   - Custom SSL delegate for self-signed homelab certificates and Tailscale HTTPS.
   - Built-in **Demo Mode** featuring comprehensive offline mock data for testing without server connectivity.

---

## 🏗️ Project Architecture & Directory Layout

```
ios/
├── Package.swift                             # Swift 6 Package definition (iOS 17+, macOS 14+)
├── project.yml                               # XcodeGen specification for regenerating Xcode project
├── ServerDeck.xcodeproj                      # Full native Xcode project configured for iOS
├── Sources/
│   └── ServerDeck/
│       ├── App/
│       │   ├── ServerDeckApp.swift           # App entry point & scene lifecycle
│       │   └── AppState.swift                # Global state coordinator & dependency injector
│       ├── Models/
│       │   ├── HostOverview.swift            # Host telemetry data model
│       │   ├── CPUStats.swift                # CPU usage, cores, model, temperature
│       │   ├── MemoryStats.swift             # RAM total, used, free, percentage
│       │   ├── DiskStats.swift               # Mount points, usage, warning flags
│       │   ├── NetworkStats.swift            # RX / TX bandwidth rates
│       │   ├── ContainersSummary.swift       # Aggregate container counters
│       │   ├── DockerContainer.swift         # Container status, stack, ports, memory
│       │   ├── ContainerStats.swift          # Live container resource usage & I/O
│       │   ├── ContainerLogs.swift           # Stdout/stderr log stream payload
│       │   ├── ServiceItem.swift             # Homelab service health & metadata
│       │   ├── WebSocketEvent.swift          # Real-time event decoder (host_tick, container_event)
│       │   ├── ActionResponse.swift          # API action outcome
│       │   └── ServerConfig.swift            # Server URL, auth token, and preferences
│       ├── Services/
│       │   ├── APIClient.swift               # REST API client, Bearer auth, custom SSL trust
│       │   ├── WebSocketManager.swift        # Live WebSocket stream with auto-reconnect
│       │   ├── KeychainService.swift         # Secure Enclave token & URL storage
│       │   ├── MockDataProvider.swift        # Comprehensive mock data for previews & demo mode
│       │   └── BiometricAuthService.swift    # Face ID / Touch ID authentication
│       ├── ViewModels/
│       │   ├── OverviewViewModel.swift       # Host telemetry presentation logic
│       │   ├── ContainersViewModel.swift     # Container filtering, search & actions
│       │   ├── ContainerDetailViewModel.swift# Real-time stats polling & terminal logs
│       │   ├── ServicesViewModel.swift       # Service categorisation & health probing
│       │   └── SettingsViewModel.swift       # Connection configuration & test ping
│       ├── Views/
│       │   ├── MainTabView.swift             # Primary 4-tab container with Quick Action triggers
│       │   ├── Common/                       # Reusable UI components
│       │   │   ├── CardView.swift            # Frosted glass card with subtle border
│       │   │   ├── StatGaugeView.swift       # Circular progress gauge with color thresholds
│       │   │   ├── DiskUsageBar.swift        # Warning-aware disk storage progress bar
│       │   │   ├── StatusBadgeView.swift     # Pulsing online/running status pill
│       │   │   └── ConnectionStatusBanner.swift # Telemetry connection indicator
│       │   ├── Overview/                     # Overview tab screens & metric cards
│       │   ├── Containers/                   # Container list, row cards, detail & terminal log
│       │   ├── Services/                     # Homelab service cards & category filters
│       │   ├── QuickActions/                 # Emergency actions & Portainer sheet
│       │   └── Settings/                     # Server settings, Face ID & Tailscale guide
│       ├── Utilities/
│       │   ├── Formatters.swift              # Thread-safe byte, rate & uptime formatters
│       │   ├── HapticManager.swift           # Tactile feedback generator wrapper
│       │   ├── Theme.swift                   # Color palette, threshold logic & materials
│       │   └── ViewExtensions.swift          # Cross-platform navigation bar modifiers
│       └── Resources/
│           ├── Info.plist                    # Permissions (Face ID, Local Network)
│           └── Assets.xcassets/              # App icon & global accent colors
└── Tests/
    └── ServerDeckTests/                      # Model decoding, formatting & mock unit tests
```

---

## 🚀 Building & Testing

### Command Line Verification

The project compiles with zero warnings or errors using standard Swift 6 toolchains:

```bash
cd /Users/andrea/Documents/Code/ServerDeck/ios

# 1. Run all unit tests
swift test

# 2. Build for iOS Simulator SDK
swift build --triple arm64-apple-ios17.0-simulator --sdk $(xcrun --show-sdk-path --sdk iphonesimulator)

# 3. Build Xcode project
xcodebuild -project ServerDeck.xcodeproj -scheme ServerDeck -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

---

## 📲 How to Install & Sideload on iPhone (Xcode & Free Personal Certificate)

You do not need a paid Apple Developer account ($99/year) to run ServerDeck on your personal iPhone. You can use your free Personal Apple ID.

### Step 1: Open the Project in Xcode
1. Double-click `ServerDeck.xcodeproj` in Finder, or in Terminal run:
   ```bash
   open /Users/andrea/Documents/Code/ServerDeck/ios/ServerDeck.xcodeproj
   ```

### Step 2: Configure Personal Signing
1. In Xcode, click the top-level **ServerDeck** project item in the left Navigator.
2. Select the **ServerDeck** target.
3. Open the **Signing & Capabilities** tab.
4. Under **Team**, select your personal Apple ID account (e.g. `Your Name (Personal Team)`).
   - If not signed in, click *Add an Account...* and sign in with your standard Apple ID.
5. In **Bundle Identifier**, if Xcode displays a bundle ID conflict, append a personal suffix (e.g., `com.andrea.ServerDeck`).

### Step 3: Connect iPhone & Run
1. Plug your iPhone into your Mac using a USB-C or Lightning cable (or enable Wireless Debugging).
2. Unlock your iPhone and tap **Trust This Computer** if prompted.
3. In Xcode's destination dropdown (at the top toolbar), select your physical iPhone.
4. Press **Cmd + R** (or click the Play button) to build and install.

### Step 4: Trust Certificate on iPhone
When launching the app for the first time, iOS will display an "Untrusted Developer" dialog. This is normal for personal sideloaded apps:
1. On your iPhone, open **Settings**.
2. Navigate to **General** ➔ **VPN & Device Management**.
3. Under **Developer App**, tap your Apple ID email address.
4. Tap **Trust "[Your Apple ID]"** and confirm.
5. Open **ServerDeck** from your Home Screen!

---

## 🔄 Handling the 7-Day Free Provisioning Expiration

Free Apple personal developer certificates expire after **7 days**. When expired, tapping the app on your iPhone will display an alert stating that the app is no longer available.

### Why ServerDeck Makes This Painless:
- **Zero Data Loss**: Your server URL and API tokens are securely stored in the iOS **Keychain**, which is preserved across re-installs.
- **Independent Backend**: The ServerDeck Go agent runs continuously on your Debian host (`srv-01`). You never need to touch or reconfigure the server when re-signing the iOS app.
- **Instant Renewal**: When the 7 days expire:
  1. Plug your iPhone into your Mac.
  2. Open `ServerDeck.xcodeproj` in Xcode.
  3. Press **Cmd + R**.
  4. The updated binary is installed directly over the existing one with all your settings, tokens, and preferences completely intact.

*(Tip: If you prefer automated wireless refreshing without plugging into Mac every 7 days, you can also export the unsigned `.ipa` and use AltStore, SideStore, or TrollStore with your personal Apple ID).*

---

## 🔒 Homelab Tailscale Setup

ServerDeck is designed to communicate with your Debian host (`srv-01`) entirely over a private Tailscale mesh network, meaning **zero public ports are exposed**:

1. **Install Tailscale on Debian (`srv-01`)**:
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```
2. **Install Tailscale on iPhone**:
   - Download **Tailscale** from the iOS App Store.
   - Sign in with the same account.
   - Switch Tailscale VPN ON.
3. **Connect ServerDeck**:
   - In ServerDeck's **Settings** tab, set:
     - **Server URL**: `http://srv-01:8080` or `http://100.x.y.z:8080` (your Tailscale IP/MagicDNS).
     - **API Token**: Your configured Bearer token.
   - Tap **Test Connection** to measure round-trip latency.
   - Tap **Save Changes**.
