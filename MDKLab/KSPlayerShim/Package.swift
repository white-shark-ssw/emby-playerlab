// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "KSPlayerShim",
    platforms: [.iOS(.v15)],
    products: [.library(name: "KSPlayer", targets: ["KSPlayer"])],
    targets: [.target(name: "KSPlayer")]
)
