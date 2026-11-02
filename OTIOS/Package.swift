// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "OtterCore",
    platforms: [
        .macOS(.v13),
        .iOS(.v15)
    ],
    products: [
        .library(name: "OtterCore", targets: ["OtterCore"])
    ],
    targets: [
        .target(
            name: "OtterCore",
            path: "Sources/OtterCore"
        ),
        .testTarget(
            name: "OtterCoreTests",
            dependencies: ["OtterCore"],
            path: "Tests/OtterCoreTests"
        )
    ]
)
