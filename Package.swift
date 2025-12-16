// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sonus",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Sonus", targets: ["Sonus"])
    ],
    targets: [
        .executableTarget(
            name: "Sonus",
            path: "Sources"
        )
    ]
)
