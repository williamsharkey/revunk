// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RevunkCore",
    products: [
        .library(
            name: "RevunkCore",
            targets: ["RevunkCore"]),
        .executable(
            name: "revunk",
            targets: ["revunk"]),
    ],
targets: [
        .target(
            name: "RevunkCore"),
        .executableTarget(
            name: "revunk",
            dependencies: ["RevunkCore"]
        ),
        .testTarget(
            name: "RevunkCoreTests",
            dependencies: ["RevunkCore"]
        ),
    ]
)
