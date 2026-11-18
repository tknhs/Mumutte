// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mumutte",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Mumutte", targets: ["Mumutte"])
    ],
    targets: [
        .executableTarget(name: "Mumutte", path: "Sources/Mumutte")
    ]
)
