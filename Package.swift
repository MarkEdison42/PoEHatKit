// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PoEHatKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PoEHatKit", targets: ["PoEHatKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
    ],
    targets: [
        // Wraps the I2C_SLAVE ioctl, which Swift cannot call under the static musl SDK.
        .target(name: "CI2C"),
        .target(name: "PoEHatKit", dependencies: [
            "CI2C",
            .product(name: "Logging", package: "swift-log"),
        ]),
        .testTarget(name: "PoEHatKitTests", dependencies: ["PoEHatKit"]),
    ]
)
