// swift-tools-version: 5.9
// Health Bee — Swift Package (for Xcode preview and compilation)

import PackageDescription

let package = Package(
    name: "HealthBee",
    platforms: [
        .iOS(.v17)
    ],
    targets: [
        .executableTarget(
            name: "HealthBee",
            path: "HealthBee",
            sources: [
                "App",
                "DesignSystem",
                "Models",
                "Components",
                "Views"
            ]
        )
    ]
)
