// swift-tools-version:5.6
import PackageDescription

let package = Package(
    name: "godot-swift",
    platforms: [.macOS("10.15.4")],
    products: [
        .plugin(name: "GodotNativeScript", targets: ["GodotNativeScript"]),
        .executable(name: "GodotNativeScriptGenerator", targets: ["GodotNativeScriptGenerator"]),
        .library(name: "GodotNative", targets: ["GodotNative"]),
    ],
    dependencies: [
        .package(url: "git@github.com:apple/swift-package-manager.git", branch: "release/5.6"),
        .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMajor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-numerics", .upToNextMinor(from: "1.0.0")),
        .package(url: "https://github.com/apple/swift-atomics", .upToNextMinor(from: "1.0.0")),
    ],
    targets: [
        .target(
            name: "GodotNative",
            dependencies: [
                "GodotNativeHeaders",
                .product(name: "Atomics", package: "swift-atomics"),
                .product(name: "Numerics", package: "swift-numerics"),
            ]
        ),
        .target(
            name: "GodotNativeHeaders",
            exclude: [
                "include/README.md", "include/LICENSE.md",
            ]
        ),
        .executableTarget(
            name: "GodotNativeScriptGenerator",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftPM-auto", package: "swift-package-manager"),
            ],
            exclude: [
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
                "gyb/nativescript.swift.part",
                "gyb/runtime.swift.part",
            ]
        ),
        .plugin(
            name: "GodotNativeScript",
            capability: .buildTool(),
            dependencies: [
                "GodotNativeScriptGenerator",
            ]
        ),
    ]
)
