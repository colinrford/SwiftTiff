// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftTiff",
    platforms: [
        .iOS(.v18),
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SwiftTiff",
            targets: ["SwiftTiff"]
        )
    ],
    targets: [
        .target(
            name: "SwiftTiff",
            path: "Sources/SwiftTiff"
        ),
        .testTarget(
            name: "SwiftTiffTests",
            dependencies: ["SwiftTiff"],
            path: "Tests/SwiftTiffTests",
            resources: [
                .copy("Resources"),
                .copy("Goldens")
            ]
        )
    ]
)
