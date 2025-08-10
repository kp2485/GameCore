// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Fizzle",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "GameDataSwiftData", targets: ["GameDataSwiftData"]),
        .library(name: "GameMap", targets: ["GameMap"])
    ],
    targets: [
        .target(name: "GameCore"),
        .target(name: "GameDataSwiftData", dependencies: ["GameCore"]),
        .target(name: "GameMap", dependencies: ["GameCore"], path: "Sources/GameMap"),
        .testTarget(name: "GameCoreTests", dependencies: ["GameCore"]),
        .testTarget(name: "GameDataSwiftDataTests", dependencies: ["GameDataSwiftData","GameCore"]),
        .testTarget(name: "GameMapTests", dependencies: ["GameMap", "GameCore"], path: "Tests/GameMapTests")
    ]
)
