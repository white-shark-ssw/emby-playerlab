// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AetherEngineOnePlayer",
    platforms: [.iOS(.v16)],
    products: [.library(name: "AetherEngine", targets: ["AetherEngine"])],
    dependencies: [.package(url: "https://github.com/mpvkit/MPVKit.git", exact: "1.0.0")],
    targets: [
        .target(
            name: "AetherEngine",
            dependencies: [.product(name: "MPVKit", package: "MPVKit", moduleAliases: ["Libdovi": "Dovi"])],
            path: "Sources/AetherEngine",
            linkerSettings: [
                .linkedFramework("AVFoundation"),
                .linkedFramework("AVKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("CoreVideo"),
                .linkedFramework("VideoToolbox"),
                .linkedFramework("AudioToolbox"),
            ]
        )
    ]
)
