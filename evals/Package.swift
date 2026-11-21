// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "bench",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "../Core")],
    targets: [
        .executableTarget(name: "bench", dependencies: [.product(name: "AckshuallyCore", package: "Core")]),
    ]
)
