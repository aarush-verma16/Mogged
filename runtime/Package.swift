// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoggedRuntime",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "MoggedRuntime", targets: ["MoggedRuntime"]),
        .executable(name: "mogged-runtime", targets: ["mogged-runtime"]),
    ],
    targets: [
        .target(
            name: "MoggedRuntime"
        ),
        .executableTarget(
            name: "mogged-runtime",
            dependencies: ["MoggedRuntime"]
        ),
        .testTarget(
            name: "MoggedRuntimeTests",
            dependencies: ["MoggedRuntime"]
        ),
    ]
)
