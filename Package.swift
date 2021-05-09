// swift-tools-version:999.0
import PackageDescription

let package = Package(
    name: "Godot",
    products: 
    [
        .plugin(    name: "GodotNativeScript",                      targets: ["GodotNativeScript"]),
        .executable(name: "GodotNativeScriptGenerator",             targets: ["GodotNativeScriptGenerator"]),
        // examples 
        .library(   name: "godot-swift-examples", type: .dynamic,   targets: ["Examples"]),
    ],
    dependencies: 
    [
        .package(url: "https://github.com/apple/swift-package-manager",     .revision("a52d4d82d2cc84ffaed3208877ccee03cc85357e")),
        .package(url: "https://github.com/apple/swift-argument-parser",     .exact("0.4.3")),
        .package(url: "https://github.com/apple/swift-numerics",            .exact("0.1.0")),
        .package(url: "https://github.com/apple/swift-atomics",             .exact("0.0.3")),
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
                "GodotNativeScriptGenerator",
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
