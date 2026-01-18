// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ephemeris",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .watchOS(.v11),
        .tvOS(.v18),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "ephemeris",
            targets: ["ephemeris"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "ephemeris",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "ephemerisTests",
            dependencies: [
                "ephemeris",
                .product(name: "Testing", package: "swift-testing")
            ]
        ),
    ]
)
