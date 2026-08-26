// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SparkleTrail",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SparkleTrail",
            path: "Sources/SparkleTrail",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
