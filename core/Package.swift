// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VunkleCore",
    products: [
        .library(
            name: "VunkleCore",
            targets: ["VunkleCore"]),
        .executable(
            name: "revunk",
            targets: ["revunk"]),
    ],
targets: [
        .target(
            name: "VunkleCore"),
        .executableTarget(
            name: "revunk",
            dependencies: ["VunkleCore"]
        ),
        .testTarget(
            name: "VunkleCoreTests",
            dependencies: ["VunkleCore"]
        ),
    ]
)
