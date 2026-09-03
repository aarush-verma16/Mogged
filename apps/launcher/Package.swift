// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Mogged",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Mogged", targets: ["Mogged"]),
    ],
    dependencies: [
        .package(path: "../../runtime"),
    ],
    targets: [
        .executableTarget(
            name: "Mogged",
            dependencies: [
                .product(name: "MoggedRuntime", package: "runtime"),
            ]
        ),
    ]
)
