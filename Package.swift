// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DesktopSticky",
    platforms: [.macOS(.v11)],
    products: [
        .executable(name: "DesktopSticky", targets: ["DesktopSticky"])
    ],
    targets: [
        .executableTarget(
            name: "DesktopSticky",
            path: "Sources/DesktopSticky"
        )
    ]
)
