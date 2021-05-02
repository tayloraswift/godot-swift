<p align="center">
    <img src="logo.svg" width="128px"/>
    <br/>
    <strong><em>Swift for Godot</em></strong> <br/> <code>0.1.0</code>
</p>

*Godot Swift* is a [Swift Package Manager](https://swift.org/package-manager/) plugin that builds and packages Swift projects as [Godot Native](https://docs.godotengine.org/en/latest/tutorials/scripting/gdnative/what_is_gdnative.html) libraries.

### getting started 

*Godot Swift* uses the experimental Swift [package plugins](https://github.com/apple/swift-evolution/blob/main/proposals/0303-swiftpm-extensible-build-tools.md) feature, which is currently only available in recent [nightly Swift toolchains](https://swift.org/download/#snapshots). Because this feature is in active development, we strongly recommend using the following Swift toolchain version to avoid compilation issues:

* **`DEVELOPMENT-SNAPSHOT-2021-04-18-a`**

> **Note:** We recommend using [`swiftenv`](https://github.com/kylef/swiftenv) to manage multiple Swift toolchain installations. You can install a custom toolchain using `swiftenv` by downloading it from [swift.org](https://swift.org/download/#snapshots) (possibly under “*Older Snapshots*”), and adding it to the `~/.swiftenv/versions/` directory, even if the snapshot is not available in `swiftenv`’s own snapshot repository.

> **Note:** Some recent Swift snapshots do not work out-of-the-box due to an incorrect `libFoundation.so` `RUNPATH` in the `libPackagePlugin.so` binary. See [this forum post](https://forums.swift.org/t/package-plugins-cannot-open-libfoundation-so/47644) for a workaround for this issue.

*Godot Swift* builds native libraries for [**Godot 3.3.0**](https://downloads.tuxfamily.org/godotengine/). 

> **Warning:** Although *Godot Swift* libraries should be compatible with later Godot versions, we *strongly recommend* using Godot 3.3.0 to avoid unrecognized-symbol errors at runtime.

### [tutorials and example programs](Examples/)

1. [basic usage](Examples/README.md#basic-usage) ([sources](Examples/basic/))
