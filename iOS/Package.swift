// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ServerDeck",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "ServerDeck",
            targets: ["ServerDeck"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ServerDeck",
            dependencies: [],
            path: "Sources/ServerDeck",
            exclude: [
                "Resources/Info.plist"
            ],
            resources: [
                .process("Resources/Assets.xcassets")
            ]
        ),
        .testTarget(
            name: "ServerDeckTests",
            dependencies: ["ServerDeck"],
            path: "Tests/ServerDeckTests"
        )
    ]
)
