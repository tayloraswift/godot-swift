// swift-tools-version:5.5
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
        .package(url: "https://github.com/apple/swift-package-manager",     .branch("main")),
        .package(url: "https://github.com/apple/swift-argument-parser",     .upToNextMinor(from: "0.4.3")),
        .package(url: "https://github.com/apple/swift-numerics",            .upToNextMinor(from: "0.1.0")),
        .package(url: "https://github.com/apple/swift-atomics",             .upToNextMinor(from: "0.0.3")),
    ],
    targets: 
    [
        .target(name: "GodotNative", dependencies: 
            [
                .target(name: "GodotNativeHeaders"),
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Numerics", package: "swift-numerics"),
            ], 
            path: "sources/godot-native"),
        .target(name:   "GodotNativeHeaders",
            path: "sources/godot-native-headers",
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
            path: "sources/godot-nativescript-generator",
            exclude: 
            [
                "api/", 
                "gyb/common-types/quaternion.swift.part",
                "gyb/common-types/transform.swift.part",
                "gyb/engine-types/aggregate.swift.part",
                "gyb/engine-types/resource-identifier.swift.part",
                "gyb/engine-types/node-path.swift.part",
                "gyb/engine-types/map.swift.part",
                "gyb/engine-types/list.swift.part",
                "gyb/engine-types/string.swift.part",
                "gyb/variant/unmanaged.swift.part",
                "gyb/variant/variant.swift.part",
                "gyb/synthesizer/common.swift.part",
                "gyb/dsl.swift.part",
                "gyb/external.swift.part",
                "gyb/runtime.swift.part",
            ]),
        .plugin(name: "GodotNativeScript", capability: .buildTool(),
            dependencies: 
            [
                "GodotNativeScriptGenerator",
            ], 
            path: "sources/godot-nativescript"),
        
        // examples 
        .target(name: "Examples", dependencies: 
            [
                "GodotNative", 
            ], 
            path: "examples/swift", 
            plugins: ["GodotNativeScript"]),
    ]
)
