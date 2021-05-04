# godot-swift tutorials

*quick reference:*

* [**types**](type-reference.md)
* [**symbol mappings**](symbol-reference.md)
* [**math library reference**](math-reference.md)

*jump to:*

1. [basic usage](#basic-usage) ([sources](swift/basic-usage.swift))
2. [advanced methods](#advanced methods) ([sources](swift/advanced-methods.swift))

## basic usage

[`sources`](swift/basic-usage.swift)

> **Key terms:** 
> - **library interface**
> - **nativescript interface**
> - **binding operator**
> - **delegate**

Start by creating two directories: `game`, which contains a Godot project, and `swift`, which will contain the Swift-language sources for a GDNative Swift library. Inside the `swift` folder, create an empty file named `library.swift`. The folder structure should look like this:

```text 
.
├── Package.swift
├── game/
│   ├── project.godot 
│   └── ...
└── swift/
    └── library.swift
```

> **Note:** There is no requirement that the Godot project directory be adjacent to the Swift sources directory. There are also no restrictions on the layout of the Swift sources, as long as the [PackageDescription API](https://developer.apple.com/documentation/swift_packages/package) can understand it.

The `Godot` package (this repository) provides two targets, [`GodotNative`](../Sources/GodotNative), and [`GodotNativeScript`](../Sources/GodotNativeScript).

Declare a target, and a product, for the Swift library as follows:

```swift 
products: 
[
    ... 
    
    .library(name: "godot-swift-examples", type: .dynamic, targets: ["Examples"]),
],

...

targets: 
[
    ...
    
    .target(name: "Examples", dependencies: 
        [
            "GodotNative", 
        ], 
        path: "swift", 
        plugins: ["GodotNativeScript"])
]
```

The library target depends on `GodotNative`, and of course, uses the `GodotNativeScript` plugin. The `GodotNative` dependency is only used by code generated from the `GodotNativeScript` plugin; you should never need to `import` it in code you write yourself.

The library product *must* be marked as a `dynamic` library product. This will direct the Swift Package Manager to build a shared library which can be loaded by the Godot engine as a [`GDNativeLibrary`](https://docs.godotengine.org/en/stable/tutorials/plugins/gdnative/gdnative-c-example.html#creating-the-gdnativelibrary-gdnlib-file).

Let’s try to compile our empty library project, using the following `swift build` invocation:

```bash 
$ SWIFTPM_ENABLE_PLUGINS=1 swift build --product godot-swift-examples -c debug
```

> **Note:** Because Swift package plugins are still an experimental feature, we must explicitly enable it by setting the `SWIFTPM_ENABLE_PLUGINS=1` environment variable. In future toolchains, this will not be necessary.

The initial build may take a while, since *Godot Swift* needs to generate and compile a large number of API bindings for Godot’s built-in classes. However, we can see that the build ultimately fails with the following errors:

```text 
(sub-build) common.swift:437:12: error: type 'Godot.Library' does not conform to protocol 'Godot.NativeLibrary'
(sub-build)     struct Library:NativeLibrary 
(sub-build)            ^
(sub-build) common.swift:381:9: note: protocol requires property 'interface' with type 'Godot.Library.Interface'; 
            do you want to add a stub?
(sub-build)     var interface:Godot.Library.Interface 
(sub-build)         ^
```

This is because the `GodotNativeScript` plugin expects you to define a **library interface** for your Swift library. A library interface specifies the Swift types available to Godot, and the nativescripts they are exported as.

We have not yet written any nativescripts, so let’s create one now. Create a new Swift file `basic-usage.swift`.

```text 
.
├── Package.swift
├── game/
│   ├── project.godot 
│   └── ...
└── swift/
    ├── library.swift
    └── basic-usage.swift
```

Declare a class `MySwiftClass` in `basic-usage.swift`, and conform it to the `Godot.NativeScript` protocol. The `Godot.NativeScript` protocol requires you to define an initializer which takes a single **delegate object** parameter. The static type of the delegate object satisfies the `associatedtype` requirement `Delegate` in the `Godot.NativeScript` protocol, and specifies the GDScript class that this nativescript should be attached to. For this example, we will assume our `MySwiftClass` nativescript will be attached to a `Godot.Unmanaged.Spatial` node ([`Godot::Spatial`](https://docs.godotengine.org/en/stable/classes/class_spatial.html)), or one of its subclasses.

We will explore delegate objects in more detail in a later tutorial. For now, we will simply ignore the delegate parameter, and define an empty initializer.

```swift 
// basic-usage.swift

final 
class MySwiftClass:Godot.NativeScript
{
    init(delegate _:Godot.Unmanaged.Spatial)
    {
    }
}
```

> **Note:** Any named Swift type (`class`, `struct`, `enum`, etc.) can be used as a nativescript, but nativescripts are immutable, so any nativescript with internal state should be defined as a `class`.

Next, we define the library interface in `library.swift` by extending the `Godot.Library` type. (This structure is generated by *Godot Swift*.) The static `interface` variable can be written as a [result builder](https://github.com/apple/swift-evolution/blob/main/proposals/0289-result-builders.md), and we can add our `MySwiftClass` type to the interface by using the **binding operator** ‘`<-`’. The nativescript type object goes on the left side of this operator, and a string containing its exported GDScript name goes on the right side.

```swift 
// library.swift 

extension Godot.Library 
{
    @Interface 
    static 
    var interface:Interface 
    {
        MySwiftClass.self <- "MyExportedSwiftClass"
    }
}
```

> **Note:** It is possible to bind the same Swift type to more than one GDScript symbol. Godot will see the bindings as separate nativescript types, but they will share the same interfaces and implementation.

Finally, let’s give it a mutable property `foo:Int`, and a method `bar(delegate:x:)`, which multiplies its `Int` parameter by `self.foo`. 

```swift
// basic-usage.swift

final 
class MySwiftClass:Godot.NativeScript
{
    init(delegate _:Godot.Unmanaged.Spatial)
    {
    }
    
    var foo:Int = 5

    func bar(delegate _:Godot.Unmanaged.Spatial, x:Int) -> Int 
    {
        self.foo * x
    }
}
```

If we try to recompile it, we will see that the build now succeeds:

```bash 
$ SWIFTPM_ENABLE_PLUGINS=1 swift build --product godot-swift-examples -c debug
```
```text
starting two-stage build...
note: searching for dynamic library products containing the target 'Examples'
note: found product 'godot-swift-examples'
note: using product 'godot-swift-examples'
...
inspecting sub-build product 'libgodot-swift-examples.so'
found 1 nativescript interface(s):
[0]: Examples.MySwiftClass <- (Godot::MyExportedSwiftClass)
{
    (0 properties)
    (0 methods)
    (0 signals)
}
synthesizing variadic templates (0 signatures)
synthesizing Godot.NativeScript conformances (1 types)
[0]: Examples.MySwiftClass
...
Build complete!
```

The *Godot Swift* plugin will log a large amount of information reporting what it detected, generated, and compiled, which we will explore in more detail in a later tutorial. For now, we can observe that it picked up the `MySwiftClass` type from the `Examples` module, and is binding it to the GDScript symbol `Godot::MyExportedSwiftClass`.

> **Warning:** *Godot Swift* will only synthesize `Godot.NativeScript` conformances for types that are declared in the library interface. If you do not declare a nativescript type in the library interface, its `Godot.NativeScript` conformance will be incomplete, and the build will fail.

We can also observe that even though we gave `MySwiftClass` a property and a method, *Godot Swift* generated no bindings for them. To make them usable from GDScript, we need to add them to the **nativescript interface** for `MySwiftClass`.

Nativescript interfaces look a lot like library interfaces. Bind properties through [`KeyPath`](https://developer.apple.com/documentation/swift/keypath)s using the `<-` operator. If the nativescript is a `class`, the keypath will instead be inferred as a [`ReferenceWritableKeyPath`](https://developer.apple.com/documentation/swift/referencewritablekeypath), which supports mutation.

You can also use the `<-` operator to bind functions to GDScript methods. The first parameter of the bound function *must* be a delegate object of the same static type as the nativescript’s associated `Delegate` type. 

A bound function can take any number of additional (strongly-typed) parameters; *Godot Swift* will generate the necessary generic templates. Any type that conforms to `Godot.VariantRepresentable` can be used as a parameter or return type. In this example, we are using `Int`, which *Godot Swift* already provides a built-in conformance for. We will learn how to define `Godot.VariantRepresentable` conformances for custom types in a later tutorial.

> **Note:** A method bound by the `<-` does not need to be a member function of the nativescript type. The only requirement is that it has the signature `(T) -> (T.Delegate, U0, U1, ... ) -> V`, where `T` is the nativescript type (in this case, `MySwiftClass`), `T.Delegate` is its associated delegate type (in this case, `Godot.Unmanaged.Spatial`), and `U0`, `U1`, `V`, etc. are its parameter and return types.
>
> Of course, any member function of the nativescript type satisfies this requirement, as long as its first parameter has the type `T.Delegate`.

We can declare an interface for `MySwiftClass` as follows: 

```swift 
// basic-usage.swift

extension MySwiftClass 
{
    @Interface 
    static 
    var interface:Interface 
    {
        Interface.properties 
        {
            \.foo <- "foo"
        }
        Interface.methods 
        {
            bar(delegate:x:) <- "bar"
        }
    }
}
```

> **Note:** The `bar(delegate:x:)` expression on the left hand side of the `<-` operator in the method list is a [curried function](https://en.wikipedia.org/wiki/Currying) of type `(MySwiftClass) -> (Godot.Unmanaged.Spatial, Int) -> Int`.

If we recompile, we can observe that *Godot Swift* is now picking up one property and one method: 

```text 
found 1 nativescript interface(s):
[0]: Examples.MySwiftClass <- (Godot::MyExportedSwiftClass)
{
    (1 property)
    (1 method)
    (0 signals)
}
```

The next step is to install our binary library products in our Godot game project. You can do this manually, as you would when using a framework like [`godot-cpp`](https://github.com/godotengine/godot-cpp), or you can use the [`build`](../build) python script (available in the repository root), which will compile the library and generate the necessary `.gdnlib` and `.gdns` resource files for you.

> **Note:** The `build` script currently only works on Linux. You can help port it to MacOS! (This should only require changing a few paths and file extensions.)

To use the `build` script, pass it an installation path, which should be a directory in your Godot project. 

```bash 
./build -c debug --install game/libraries
```
```text 
installing to 'res://libraries/' in project 'game'
```

On script termination, you should now see the Swift library files installed in the `game` project at the specified path: 

```text 
.
└── game/
    ├── project.godot 
    └── libraries/
        ├── godot-swift-examples/ 
        │   ├── library.gdnlib 
        │   └── MyExportedSwiftClass.gdns
        ├── libgodot-swift-examples.so
        └── libSwiftPM.so
```

Now, let’s open up the Godot editor, and create a simple scene `main.tscn`, and a script `main.gd`.

```text 
.
└── game/
    ├── main.tscn 
    ├── main.gd 
    ├── project.godot 
    └── libraries/
        ├── godot-swift-examples/ 
        │   ├── library.gdnlib 
        │   └── MyExportedSwiftClass.gdns
        ├── libgodot-swift-examples.so
        └── libSwiftPM.so
```

In the `main.tscn` scene, create two nodes: a root node `root`, and a child node `root/delegate`, of type `Godot::Spatial`:

```text 
○ root:Node 
└── ○ delegate:Spatial 
```

Attach the `MyExportedSwiftClass.gdns` nativescript to the `root/delegate` node, and attach the `main.gd` script to the `root` node. 

```text 
○ root:Node             (main.gd)
└── ○ delegate:Spatial  (MyExportedSwiftClass.gdns)
```

In the `main.gd` script, add the following code, which interacts with its `delegate` child: 

```gdscript 
extends Node

func _ready():
    print($delegate.foo)
    
    print($delegate.bar(2))
    
    $delegate.foo += 1
    
    print($delegate.foo)
    print($delegate.bar(3))
```

If we run the game, we can now see the Swift library working as expected.

```text 
(swift) registering MySwiftClass as nativescript 'Godot::MyExportedSwiftClass'
(swift) registering (function) as method 'Godot::MyExportedSwiftClass::bar'
(swift) registering (function) as property 'Godot::MyExportedSwiftClass::foo'
5
10
6
18
```

## advanced methods 

[`sources`](swift/advanced-methods.swift)

> This tutorial assumes you already have the project from the [basic usage](#basic-usage) tutorial set up.

Add a new source file, `advanced-methods.swift` to the Swift library.

```text 
.
├── Package.swift
├── game/
│   ├── project.godot 
│   ├── main.tscn 
│   ├── main.gd 
│   ├── libraries/ 
│   └── ...
└── swift/
    ├── library.swift
    ├── basic-usage.swift
    └── advanced-methods.swift
```

Define a new nativescript class, `SwiftAdvancedMethods`, and add it to the library interface in `library.swift`

```swift 
// advanced-methods.swift 

final 
class SwiftAdvancedMethods:Godot.NativeScript
{
    init(delegate _:Godot.Unmanaged.Spatial)
    {
    }
```

```swift 
// library.swift 

extension Godot.Library 
{
    @Interface 
    static 
    var interface:Interface 
    {
        MySwiftClass.self           <- "MyExportedSwiftClass"
        SwiftAdvancedMethods.self   <- "SwiftAdvancedMethods"
    }
}
```

Now, let’s explore some of the kinds of nativescript methods we can write using *Godot Swift*.

Although there aren’t many good use cases for this, you can define a method that takes a `Godot::null` argument by specifying its type in Swift as `Void` (sometimes written as the empty tuple `()`).

```swift 
    func voidArgument(delegate _:Godot.Unmanaged.Spatial, void _:Void)  
    {
        Godot.print("hello from \(#function)")
    }
```

A `Void` argument does not mean “no argument”; you must call such a function from GDScript by explicitly passing `null`.

```gdscript 
    $delegate.void_argument(null)
```

Any `Godot.VariantRepresentable` type can be used as a method parameter type. For example, `Optional<Int>` is variant-representable (by the union type of `Godot::null` and `Godot::int`), which means we can define the following method: 

```swift 
    func optionalArgument(delegate _:Godot.Unmanaged.Spatial, int:Int?)  
    {
        Godot.print("hello from \(#function), recieved \(int as Any)")
    }
```

Such a method can be called from GDScript with either an integer argument, or `null`. 

```gdscript 
    $delegate.optional_argument(10)
    $delegate.optional_argument(null)
```
