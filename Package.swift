// swift-tools-version:999.0

import PackageDescription

let package = Package(
    name: "Godot",
    products: 
    [
        .plugin(name: "GodotNativeScript", targets: ["GodotNativeScript"]),
        // examples 
        .library(name: "godot-swift-examples", type: .dynamic, targets: ["Examples"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/apple/swift-numerics",        .upToNextMinor(from: "0.1.0")),
        .package(url: "https://github.com/apple/swift-atomics.git",     .upToNextMinor(from: "0.0.1")),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.1")),
        .package(url: "https://github.com/apple/swift-package-manager", .branch("main")),
    ],
    targets: 
    [
        .target(name: "GodotNative", dependencies: 
            [
                .target(name: "GodotNativeHeaders"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Numerics", package: "swift-numerics"),
            ]),
        .target(name: "GodotNativeHeaders",
            exclude: 
            [
                "include/README.md", "include/LICENSE.md"
            ]),
        .executableTarget(name: "GodotNativeScriptGenerator",
            dependencies: 
            [
                .product(name: "ArgumentParser",    package: "swift-argument-parser"),
                .product(name: "SwiftPM",           package: "swift-package-manager"), 
            ],
            exclude: 
            [
                "fragments/", "api/", 
            ]),
        .plugin(name: "GodotNativeScript", capability: .buildTool(),
            dependencies: 
            [
                "GodotNativeScriptGenerator"
            ]),
        
        // examples 
        .target(name: "Examples", dependencies: 
            [
                "GodotNative", 
            ], 
            path: "Examples/swift", 
            plugins: ["GodotNativeScript"]),
    ]
)
