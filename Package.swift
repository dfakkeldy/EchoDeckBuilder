// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "EchoDeckBuilder",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "EchoDeckBuilder", targets: ["EchoDeckBuilder"])
    ],
    targets: [
        .executableTarget(
            name: "EchoDeckBuilder",
            path: "Sources/EchoDeckBuilder"
        ),
        .testTarget(
            name: "EchoDeckBuilderTests",
            dependencies: ["EchoDeckBuilder"],
            path: "Tests/EchoDeckBuilderTests"
        )
    ]
)
