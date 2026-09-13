// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Deskbit",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "Deskbit", targets: ["Deskbit"])
    ],
    targets: [
        .executableTarget(
            name: "Deskbit",
            path: "Sources/Deskbit"
        )
    ]
)
