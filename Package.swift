// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Fizzle",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "GameMap", targets: ["GameMap"]),
        .library(name: "GameDataSwiftData", targets: ["GameDataSwiftData"]),
    ],
    targets: [
        .target(
            name: "GameCore",
            dependencies: [],
            path: "Sources/GameCore"
        ),
        .target(
            name: "GameMap",
            dependencies: ["GameCore"],
            path: "Sources/GameMap"
        ),
        .target(
            name: "GameDataSwiftData",
            dependencies: ["GameCore", "GameMap"],
            path: "Sources/GameDataSwiftData"
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"],
            path: "Tests/GameCoreTests"
        ),
        .testTarget(
            name: "GameMapTests",
            dependencies: ["GameMap", "GameCore"],
            path: "Tests/GameMapTests"
        ),
        .testTarget(
            name: "GameDataSwiftDataTests",
            dependencies: ["GameDataSwiftData", "GameMap", "GameCore"],
            path: "Tests/GameDataSwiftDataTests"
        )
    ]
)
