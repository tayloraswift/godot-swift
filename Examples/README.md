# godot-swift tutorials

*quick reference:*

* [**types**](type-reference.md)
* [**symbol mappings**](symbol-reference.md)
* [**math library reference**](math-reference.md)

*jump to:*

1. [basic usage](#basic-usage) ([sources](swift/basic-usage.swift))
2. [advanced methods](#advanced-methods) ([sources](swift/advanced-methods.swift))
3. [advanced properties](#advanced-properties) ([sources](swift/advanced-properties.swift))
4. [signals](#signals) ([sources](swift/signals.swift))
5. [life cycle management](#life-cycle-management) ([sources](swift/life-cycle-management.swift))
6. [using custom types](#using-custom-types) ([sources](swift/custom-types.swift))
7. [procedural geometry](#procedural-geometry) ([sources](swift/procedural-geometry.swift))

## basic usage

[`sources`](swift/basic-usage.swift)

> **Key terms:** 
> - **library interface**
> - **nativescript interface**
> - **binding operator**
> - **delegate**

#### getting started 

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

#### installing library resources

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

> **Key terms:** 
> - **tuple splatting**

> This tutorial assumes you already have the project from the [basic usage](#basic-usage) tutorial set up.

Add a new source file, `advanced-methods.swift`, to the Swift library.

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

#### `Void` parameters

Although there aren’t many good use cases for this, you can define a method that takes a `Godot::null` parameter by specifying its type in Swift as `Void` (sometimes written as the empty tuple `()`).

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

#### `Optional` parameters

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

#### multiple parameters 

Methods can take any number of parameters, as long as the first parameter is `Self.Delegate`. The trailing parameters must be `Godot.VariantRepresentable`, but there is no requirement that they be of the same type. *Godot Swift* will generate the necessary variadic generic templates for you.

```swift 
    func multipleArguments(delegate _:Godot.Unmanaged.Spatial, 
        bool:Bool, int:Int16, vector:Vector2<Float64>)  
    {
        Godot.print("hello from \(#function), recieved \(bool), \(int), \(vector)")
    }
```

You can find a list of all the built-in `Godot.VariantRepresentable` types you can use in the [type reference](type-reference.md).

#### tuple splatting

*Godot Swift* supports **tuple splatting**. This feature allows you to automatically destructure `Godot::Array` parameters into strongly-typed tuple forms. 

```swift 
    func tupleArgument(delegate _:Godot.Unmanaged.Spatial, tuple:(String, (String, String)))  
    {
        Godot.print("hello from \(#function), recieved \(tuple)")
    }
```

To call such a function from GDScript, pass it a `Godot::Array` of the expected form:

```gdscript 
    var strings:Array = [
            'element (0)', [
                'element (1, 0)', 
                'element (1, 1)'
            ]
        ]
    
    $delegate.tuple_argument(strings)
```

You can also specify the Swift type of a `Godot::Array` parameter as `Godot.List`, to receive variable-length, type-erased Godot lists: 

```swift 
    func listArgument(delegate _:Godot.Unmanaged.Spatial, list:Godot.List)  
    {
        Godot.print("hello from \(#function), recieved list (\(list.count) elements)")
        for (i, element):(Int, Godot.Variant?) in list.enumerated()
        {
            Godot.print("[\(i)]: \(element as Any)")
        }
    }
```

Both forms are called in the exact same way from GDScript.

#### `inout` parameters

*Godot Swift* supports `inout` parameters. 

```swift 
    func inoutArgument(delegate _:Godot.Unmanaged.Spatial, int:inout Int)  
    {
        Godot.print("hello from \(#function)")
        int += 2
    }
```

When called from GDScript, the integer argument passed to this function will be updated when the method returns.

Tuple splatting also works with `inout`. 

```swift 
    func inoutTupleArgument(delegate _:Godot.Unmanaged.Spatial, tuple:inout (String, (String, String)))  
    {
        Godot.print("hello from \(#function), recieved \(tuple)")
        tuple.1.0 = "new string"
    }
```

The list elements are updated individually. Overwriting the entire tuple aggregate does not replace the `Godot::Array` instance itself.

> **Warning:** GDScript has no concept of `inout` parameters, which means that modifying passed arguments may constitute unexpected behavior. Swift methods that modify their arguments should be clearly documented as such.

#### return values 

Any `Godot.VariantRepresentable` type can be used as a method return type. For example, we can return an `Optional<Int>` as follows: 

```swift 
    func optionalReturn(delegate _:Godot.Unmanaged.Spatial, int:Int) -> Int?  
    {
        int < 0 ? nil : int
    }
```

Tuple splatting also works with return values. The following nativescript method produces a two-element `Godot::Array` when called from GDScript: 

```swift 
    func tupleReturn(delegate _:Godot.Unmanaged.Spatial) -> (Float32, Float64?)  
    {
        return (.pi, nil)
    }
}
```

The first element will become a `Godot::float` in GDScript, and the second element will become either a `Godot::float`, or `Godot::null`.

#### putting it together 

Before we can test our *Godot Swift* methods in GDScript, we need to add them to `SwiftAdvancedMethods`’s nativescript interface. 

```swift 
// advanced-methods.swift 

extension SwiftAdvancedMethods 
{
    @Interface 
    static 
    var interface:Interface 
    {
        Interface.methods 
        {
            voidArgument(delegate:void:)                    <- "void_argument"
            optionalArgument(delegate:int:)                 <- "optional_argument"
            multipleArguments(delegate:bool:int:vector:)    <- "multiple_arguments"
            tupleArgument(delegate:tuple:)                  <- "tuple_argument"
            listArgument(delegate:list:)                    <- "list_argument"
            
            inoutArgument(delegate:int:)                    <- "inout_argument"
            inoutTupleArgument(delegate:tuple:)             <- "inout_tuple_argument"
            
            optionalReturn(delegate:int:)                   <- "optional_return"
            tupleReturn(delegate:)                          <- "tuple_return"
        }
    }
}
```

Compile and install the Swift library using the `build` script: 

```bash 
$ ./build -c debug -i Examples/game/libraries
```

```text 
...
inspecting sub-build product 'libgodot-swift-examples.so'
note: in directory '.build/plugins/outputs/godot-swift/Examples/GodotNativeScript/.build/debug'
note: through entrypoint '__inspector_entrypoint_loader__'
found 2 nativescript interface(s):
[0]: Examples.MySwiftClass <- (Godot::MyExportedSwiftClass)
{
    (1 property)
    (1 method)
    (0 signals)
}
[1]: Examples.SwiftAdvancedMethods <- (Godot::SwiftAdvancedMethods)
{
    (0 properties)
    (9 methods)
    (0 signals)
}
generating file 'registration.swift'
note: in directory '.build/plugins/outputs/godot-swift/Examples/GodotNativeScript'
synthesizing variadic templates (8 signatures)
[0]: (T.Delegate) -> (V0, V1)
[1]: (T.Delegate, (U0, (U1, U2))) -> Void
[2]: (T.Delegate, U0) -> V0
[3]: (T.Delegate, U0) -> Void
[4]: (T.Delegate, U0, U1, U2) -> Void
[5]: (T.Delegate, Void) -> Void
[6]: (T.Delegate, inout (U0, (U1, U2))) -> Void
[7]: (T.Delegate, inout U0) -> Void
synthesizing Godot.NativeScript conformances (2 types)
[0]: Examples.MySwiftClass
[1]: Examples.SwiftAdvancedMethods
...
installing to 'res://libraries/' in project 'game'
```

We can observe that *Godot Swift* generated eight generic templates, covering the signatures of the nine methods we defined on `SwiftAdvancedMethods`. (The `optionalArgument(delegate:int:)` and `listArgument(delegate:list:)` methods share a single template.)

Add a new scene, `advanced-methods.tscn`, to the Godot project, and give it a root node `root` and a child node `delegate` of type `Godot::Spatial`. Create a GDScript script `advanced-methods.gd`, and attach it to the root node.

```text 
.
└── game/
    ├── project.godot 
    ├── main.tscn 
    ├── main.gd 
    ├── advanced-methods.tscn 
    ├── advanced-methods.gd 
    └── libraries/
        ├── godot-swift-examples/ 
        │   ├── library.gdnlib 
        │   ├── MyExportedSwiftClass.gdns
        │   └── SwiftAdvancedMethods.gdns
        ├── libgodot-swift-examples.so
        └── libSwiftPM.so
```

Attach the `SwiftAdvancedMethods` nativescript to the `delegate` node.

```text 
// advanced-methods.tscn

○ root:Node             (advanced-methods.gd)
└── ○ delegate:Spatial  (SwiftAdvancedMethods.gdns)
```

Add the following demo code to the `advanced-methods.gd` script: 

```gdscript 
extends Node

func _ready():
    $delegate.void_argument(null)
    
    $delegate.optional_argument(10)
    $delegate.optional_argument(null)
    
    $delegate.multiple_arguments(true, 3, Vector2(0.5, 0.75))
    
    var strings:Array = [
        'element (0)', [
            'element (1, 0)', 
            'element (1, 1)'
        ]
    ]
    
    $delegate.tuple_argument(strings)
    $delegate.list_argument(strings)
    
    var x:int = 5 
    print('old value of `x`: ', x)
    $delegate.inout_argument(x)
    print('new value of `x`: ', x)
    
    print('old value of `strings`: ', strings)
    $delegate.inout_tuple_argument(strings)
    print('new value of `strings`: ', strings)
    
    print('non-negative: ', $delegate.optional_return( 1))
    print('non-negative: ', $delegate.optional_return(-1))

    print('returned tuple: ', $delegate.tuple_return())
```

If we launch the `advanced-methods.tscn` scene from the Godot editor, we can see the Swift methods in action. Output printed from Swift is prefixed with the string `'(swift)'`; output printed from GDScript is emitted as-is.

```text 
(swift) registering MySwiftClass as nativescript 'Godot::MyExportedSwiftClass'
(swift) registering (function) as method 'Godot::MyExportedSwiftClass::bar'
(swift) registering (function) as property 'Godot::MyExportedSwiftClass::foo'
(swift) registering SwiftAdvancedMethods as nativescript 'Godot::SwiftAdvancedMethods'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::void_argument'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::optional_argument'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::multiple_arguments'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::tuple_argument'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::list_argument'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::inout_argument'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::inout_tuple_argument'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::optional_return'
(swift) registering (function) as method 'Godot::SwiftAdvancedMethods::tuple_return'
(swift) hello from voidArgument(delegate:void:)
(swift) hello from optionalArgument(delegate:int:), recieved Optional(10)
(swift) hello from optionalArgument(delegate:int:), recieved nil
(swift) hello from multipleArguments(delegate:bool:int:vector:), recieved true, 3, Vector(0.5, 0.75)
(swift) hello from tupleArgument(delegate:tuple:), recieved ("element (0)", ("element (1, 0)", "element (1, 1)"))
(swift) hello from listArgument(delegate:list:), recieved list (2 elements)
(swift) [0]: Optional(Examples.Godot.String)
(swift) [1]: Optional(Examples.Godot.List)
old value of `x`: 5
(swift) hello from inoutArgument(delegate:int:)
new value of `x`: 7
old value of `strings`: [element (0), [element (1, 0), element (1, 1)]]
(swift) hello from inoutTupleArgument(delegate:tuple:), recieved ("element (0)", ("element (1, 0)", "element (1, 1)"))
new value of `strings`: [element (0), [new string, element (1, 1)]]
non-negative: 1
non-negative: Null
returned tuple: [3.141593, Null]
```

## advanced properties

[`sources`](swift/advanced-properties.swift)

> This tutorial assumes you already have the project from the [basic usage](#basic-usage) tutorial set up.

Define a new nativescript class, `SwiftAdvancedProperties`, in `advanced-properties.swift`, and add it to the library interface in `library.swift`.

```text 
.
├── Package.swift
├── game/
│   ├── project.godot 
│   ├── main.tscn 
│   ├── main.gd 
│   ├── advanced-methods.tscn 
│   ├── advanced-methods.gd 
│   ├── libraries/ 
│   └── ...
└── swift/
    ├── library.swift
    ├── basic-usage.swift
    ├── advanced-methods.swift
    └── advanced-properties.swift
```

```swift 
// advanced-properties.swift 

final 
class SwiftAdvancedProperties:Godot.NativeScript 
{
    var radians:Float64 
    var degrees:Float64 
    {
        self.radians * 180.0 / .pi
    }
    
    private 
    var array:[Int]
    
    init(delegate _:Godot.Unmanaged.Spatial)
    {
        self.radians    = 0.5 * .pi
        self.array      = [10, 11, 12]
    }
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
        MySwiftClass.self               <- "MyExportedSwiftClass"
        SwiftAdvancedMethods.self       <- "SwiftAdvancedMethods"
        SwiftAdvancedProperties.self    <- "SwiftAdvancedProperties"
    }
}
```

We already saw in the [basic usage](#basic-usage) tutorial how to register a settable property, by using a [`ReferenceWritableKeyPath`](https://developer.apple.com/documentation/swift/ReferenceWritableKeyPath).

```swift 
// advanced-properties.swift 

extension SwiftAdvancedProperties
{
    @Interface 
    static 
    var interface:Interface 
    {
        Interface.properties 
        {
            \.radians   <- "radians"
```

We can also export a get-only property, by using an ordinary, immutable [`KeyPath`](https://developer.apple.com/documentation/swift/KeyPath). 

```swift 
            \.degrees   <- "degrees"
```

Attempting to set to a get-only property from GDScript is an error. 

```gdscript 
    $delegate.degrees = 5
```

```text 
ERROR: <-(_:_:): (swift) cannot assign to get-only property 'degrees'
```

> **Note:** The Swift type inferencer will prefer `ReferenceWritableKeyPath` over `KeyPath` if the target property is settable.

Any valid Swift keypath can be used as a GDScript property accessor. For example, we can expose elements in `self.array` by using subscript keypaths:

```swift 
            \.array[0]  <- "elements_0"
            \.array[1]  <- "elements_1"
            \.array[2]  <- "elements_2"
        }
    }
}
```

> **Note:** Indexed GDScript properties are not supported (yet).

We can build, install, and demo the `SwiftAdvancedProperties` nativescript in a new scene `advanced-properties.tscn`.

```text 
.
└── game/
    ├── project.godot 
    ├── main.tscn 
    ├── main.gd 
    ├── advanced-methods.tscn 
    ├── advanced-methods.gd 
    ├── advanced-properties.tscn 
    ├── advanced-properties.gd 
    └── libraries/
        ├── godot-swift-examples/ 
        │   ├── library.gdnlib 
        │   ├── MyExportedSwiftClass.gdns
        │   └── SwiftAdvancedMethods.gdns
        │   └── SwiftAdvancedProperties.gdns
        ├── libgodot-swift-examples.so
        └── libSwiftPM.so
```

```text 
// advanced-properties.tscn

○ root:Node             (advanced-properties.gd)
└── ○ delegate:Spatial  (SwiftAdvancedProperties.gdns)
```

```gdscript 
# advanced-properties.gd

extends Node

func _ready():
    print('radians: ', $delegate.radians)
    print('degrees: ', $delegate.degrees)
    $delegate.radians = 0.678 * PI
    print('radians: ', $delegate.radians)
    print('degrees: ', $delegate.degrees)
    
    # $delegate.degrees = 5
    
    print('element 0: ', $delegate.elements_0)
    print('element 1: ', $delegate.elements_1)
    print('element 2: ', $delegate.elements_2)
```

```text 
... 
(swift) registering SwiftAdvancedProperties as nativescript 'Godot::SwiftAdvancedProperties'
(swift) registering (function) as property 'Godot::SwiftAdvancedProperties::radians'
(swift) registering (function) as property 'Godot::SwiftAdvancedProperties::degrees'
(swift) registering (function) as property 'Godot::SwiftAdvancedProperties::elements_0'
(swift) registering (function) as property 'Godot::SwiftAdvancedProperties::elements_1'
(swift) registering (function) as property 'Godot::SwiftAdvancedProperties::elements_2'
radians: 1.570796
degrees: 90
radians: 2.13
degrees: 122.04
element 0: 10
element 1: 11
element 2: 12
```
