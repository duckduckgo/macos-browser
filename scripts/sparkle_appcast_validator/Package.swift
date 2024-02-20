// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "sparkle-appcast-validator",
    platforms: [
        .macOS(.v11),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle.git", exact: "2.5.2"),
    ],
    targets: [
        .target(
            name: "SparklePrivateHeaders",
            dependencies: [
                "Sparkle"
            ],
            publicHeadersPath:"include"
        ),

        .executableTarget(
            name: "sparkle-appcast-validator",
            dependencies: [
                "Sparkle",
                "SparklePrivateHeaders"
            ],
            publicHeadersPath: "include"
        )
    ]
)
