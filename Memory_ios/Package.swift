// swift-tools-version: 5.9
// This file is provided as a reference for building with Swift Package Manager.
// The primary build system is Xcode (Memory.xcodeproj).

import PackageDescription

let package = Package(
    name: "Memory",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Memory", targets: ["Memory"]),
    ],
    targets: [
        .target(
            name: "Memory",
            path: "Memory"
        ),
        .testTarget(
            name: "MemoryTests",
            dependencies: ["Memory"],
            path: "MemoryTests"
        ),
    ]
)
