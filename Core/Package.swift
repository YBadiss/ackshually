// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "AckshuallyCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "AckshuallyCore", targets: ["AckshuallyCore"]),
    ],
    targets: [
        .target(name: "AckshuallyCore"),
        .testTarget(name: "AckshuallyCoreTests", dependencies: ["AckshuallyCore"]),
    ]
)
