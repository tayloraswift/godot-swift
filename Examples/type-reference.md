# type reference

## variants 

All variables in GDScript have the type `Godot::Variant`, which is a union type abstracting over 27 distinct [**core types**](https://docs.godotengine.org/en/stable/getting_started/scripting/gdscript/gdscript_basics.html#built-in-types). This is true even when GDScript is written with type annotations, as they really behave more like runtime assertions than a true static typing system.

```text 
Godot::Variant    ::= Godot::null
                    | Godot::bool 
                    | Godot::int 
                    | Godot::float

                    | Godot::String
                    | Godot::Array
                    | Godot::Dictionary  
    
                    | Godot::Vector2
                    | Godot::Vector3
                    | Godot::Color 
                    | Godot::Rect2 
                    | Godot::AABB  
                    | Godot::Quat 
                    | Godot::Plane 
                    | Godot::Transform2D 
                    | Godot::Transform 
                    | Godot::Basis  

                    | Godot::RID
                    | Godot::NodePath
                    | Godot::Object

                    | Godot::PoolByteArray
                    | Godot::PoolIntArray
                    | Godot::PoolRealArray
                    | Godot::PoolVector2Array
                    | Godot::PoolVector3Array
                    | Godot::PoolColorArray
                    | Godot::PoolStringArray
```

In *Godot Swift*, variants are modeled as `Godot.Variant?` existentials. Each core type (except for `Godot::null`) is modeled by a concrete type conforming to the protocol `Godot.Variant`:

```swift 
Swift.Bool                              :Godot.Variant
Swift.Int64                             :Godot.Variant
Swift.Float64                           :Godot.Variant
```
```swift 
Godot.String                            :Godot.Variant
Godot.List                              :Godot.Variant
Godot.Map                               :Godot.Variant
```
```swift 
Vector2<Swift.Float32>                  :Godot.Variant
Vector3<Swift.Float32>                  :Godot.Variant
Vector4<Swift.Float32>                  :Godot.Variant
Vector2<Swift.Float32>.Rectangle        :Godot.Variant
Vector3<Swift.Float32>.Rectangle        :Godot.Variant
Quaternion<Swift.Float32>               :Godot.Variant

Godot.Plane3<Swift.Float32>             :Godot.Variant
Godot.Transform2<Swift.Float32>.Affine  :Godot.Variant
Godot.Transform3<Swift.Float32>.Affine  :Godot.Variant
Godot.Transform3<Swift.Float32>.Linear  :Godot.Variant
```
```swift 
Godot.ResourceIdentifier                :Godot.Variant
Godot.NodePath                          :Godot.Variant
Godot.AnyDelegate                       :Godot.Variant
```
```swift 
Godot.Array<Swift.UInt8>                :Godot.Variant
Godot.Array<Swift.Int32>                :Godot.Variant
Godot.Array<Swift.Float32>              :Godot.Variant
Godot.Array<Vector2<Swift.Float32>>     :Godot.Variant
Godot.Array<Vector3<Swift.Float32>>     :Godot.Variant
Godot.Array<Vector4<Swift.Float32>>     :Godot.Variant
Godot.Array<Swift.String>               :Godot.Variant
```

The `Godot::null` type is then represented by the `nil` case of `Optional<Godot.Variant>`, which completes the fully-unified existential type.

> **Warning:** Do not conform additional types to `Godot.Variant` in user code. 

The concrete *Godot Swift* types are detailed in the next few sections.

## general purpose types 

### [`Void`](https://developer.apple.com/documentation/swift/void) (`Godot::null`)

The `Godot::null` type in GDScript corresponds to `Void` in Swift (sometimes written as the empty tuple `()`). 

Keep in mind that `Void` is not a type case of `Godot.Variant`, which is why we refer to the *optional* type `Godot.Variant?` as corresponding to `Godot::Variant`. In other words, the wrapped `Godot.Variant` existential models the 26 non-null GDScript types only.

### [`Bool`](https://developer.apple.com/documentation/swift/bool) (`Godot::bool`)

The `Godot::bool` type in GDScript corresponds to `Bool` in Swift, which is fairly self-explanatory.

### [`Int64`](https://developer.apple.com/documentation/swift/int64) (`Godot::int`)

The `Godot::int` type in GDScript corresponds to `Int64` in Swift. It is rarely necessary to use `Int64` directly in user code, as most Swift integer types, including `Int`, conform to `Godot.VariantRepresentable` (explained in a later section).

### [`Float64`](https://developer.apple.com/documentation/swift/double) (`Godot::float`)

The `Godot::float` type in GDScript corresponds to `Float64` (`Double`) in Swift. Although `Float64` is the canonical floating point type in Swift, in some cases, it may be preferable to use a floating point type of a different precision, such as `Float16` or `Float32` (`Float`). In such cases, it is rarely necessary to explicitly convert from `Float64` in user code, as `Float16` and `Float32` both conform to `Godot.VariantRepresentable` (explained in a later section).

### `Godot.String` (`Godot::String`)

The `Godot::String` type in GDScript corresponds to the *Godot Swift* type `Godot.String`. It is rarely necessary to use `Godot.String` directly in user code, as Swift’s native `String` type conforms to `Godot.VariantRepresentable`. 

The `Godot.String` type is an opaque wrapper around a `Godot::String` object, and it supports no functionality other than converting to and from a native Swift `String`. The main purpose of this type is to allow strings and variant existentials to be moved without copying the underlying string buffer, in situations where it is not necessary to interact with the actual contents of the string.

Convert between `String` and `Godot.String` using the `init(_:)`’s on each type:

```swift 
let godot:Godot.String = ...
let swift:Swift.String = .init(godot)
```
```swift 
let swift:Swift.String = ...
let godot:Godot.String = .init(swift)
```

Instances of `Godot.String` are memory-managed by Swift.

### `Godot.List` (`Godot::Array`)

The `Godot::Array` type in GDScript corresponds to the *Godot Swift* type `Godot.List`.

Despite its name, the `Godot::Array` type is semantically equivalent to an `inout` Swift tuple, and in many situations, *Godot Swift* allows you to bridge `Godot::Array`’s directly to Swift tuple types, without having to go through `Godot.List` intermediates.

> **Warning:** Do not confuse `Godot.List` with `Godot.Array<T>`. `Godot.Array<T>` corresponds to the *pooled* array types in GDScript.

The `Godot.List` type is an opaque wrapper around a `Godot::Array` object, and it supports no functionality other than minimal conformances to [`RandomAccessCollection`](https://developer.apple.com/documentation/swift/randomaccesscollection) and [`MutableCollection`](https://developer.apple.com/documentation/swift/mutablecollection). The main purpose of this type is to allow lists and variant existentials to be moved or subscripted without copying the entire underlying list buffer, in situations where it is not necessary to interact with all of the actual elements of the list.

The `Element` type of a `Godot.List` is a `Godot.Variant?` existential. (Note the double optional returned by the [`first`](https://developer.apple.com/documentation/swift/collection/3017676-first) property.)

```swift 
let list:Godot.List         = ... 
let element:Godot.Variant?? = list.first 
```

Instances of `Godot.List` have reference semantics. (Note the `let` declaration, as opposed to a `var` declaration.)

```swift 
let list:Godot.List     = ... 
list[list.startIndex]   = nil 
```

Create a list with capacity for a specified number of elements using the `init(count:)` convenience initializer:

```swift 
let count:Int       = ...
let list:Godot.List = .init(count: count)
```

> **Note:** This initializer is called `init(count:)` and not `init(capacity:)`, because all list elements are initialized — to `nil`. Godot has no concept of uninitialized list memory.

You can also dynamically resize a list using the `resize(to:)` method.

```swift 
let count:Int       = ...
let list:Godot.List = .init()
list.resize(to: count)
```

All newly-allocated positions in a `Godot.List` are initialized to `nil`.

The `Godot.List` type is [`ExpressibleByArrayLiteral`](https://developer.apple.com/documentation/swift/expressiblebyarrayliteral).

```swift 
let list:Godot.List = 
[
    nil  as Godot.Variant?, 
    3.14 as Godot.Variant?,
    5    as Godot.Variant?
]
```

You can convert a `Godot.List` to a `[Godot.Variant?]` array, just like any other Swift [`Sequence`](https://developer.apple.com/documentation/swift/sequence).

```swift 
let list:Godot.List             = ... 
let variants:[Godot.Variant?]   = .init(list)
```

Instances of `Godot.List` are memory-managed by Swift. When a `Godot.List` is deinitialized by the Swift runtime, all of its elements are also deinitialized.

### `Godot.Map` (`Godot::Dictionary`)

The `Godot::Dictionary` type in GDScript corresponds to the *Godot Swift* type `Godot.Map`. It has no semantic equivalent in Swift, but it behaves somewhat similarly to a severely type-erased `inout` Swift `Dictionary`.

The `Godot.Map` type is an opaque wrapper around a `Godot::Dictionary` object, and it supports no functionality other than basic key-to-value subscripts.

The `Godot.Map` type cannot store `Void` values, because it uses the `nil` case of `Godot.Variant?` to represent key-value pairs not present in the unordered map. Accordingly, its key-to-value subscript is *non-optional* with respect to `Godot.Variant?`. (Note the single optional in its return type.)

```swift 
let map:Godot.Map           = ...
let key:Godot.Variant?      = ... 
let value:Godot.Variant?    = map[key]
```

Instances of `Godot.Map` have reference semantics. (Note the `let` declaration, as opposed to a `var` declaration.)

```swift 
let map:Godot.List      = ... 
let key:Godot.Variant?  = ... 
map[key]                = nil 
```

It is currently not possible to convert a `Godot.Map` instance to a Swift `[Godot.Variant?: Godot.Variant]` dictionary, because protocol existential types are not [`Hashable`](https://developer.apple.com/documentation/swift/hashable).

The `Godot.Map` type is [`ExpressibleByDictionaryLiteral`](https://developer.apple.com/documentation/swift/expressiblebydictionaryliteral).

```swift 
let map:Godot.Map = 
[
    nil  as Godot.Variant?: 5     as Godot.Variant, 
    3.14 as Godot.Variant?: 3.14  as Godot.Variant,
    5    as Godot.Variant?: false as Godot.Variant
]
```

Instances of `Godot.Map` are memory-managed by Swift. When a `Godot.Map` is deinitialized by the Swift runtime, all of its keys and values are also deinitialized.

## math types 

Math types in *Godot Swift* are all generic over [`BinaryFloatingPoint`](https://developer.apple.com/documentation/swift/binaryfloatingpoint)` & `[`SIMDScalar`](https://developer.apple.com/documentation/swift/simdscalar). For each math type, the specialization for `Float32` forms the canonical `Godot.Variant` type, with all other specializations conforming to `Godot.VariantRepresentable`. This makes it possible to write user code that is generic over `BinaryFloatingPoint & SIMDScalar` in most situations. 

> **Note:** Recall that `Float32` by itself is *not* a `Godot.Variant` type; `Float64` (`Double`) is. The Godot engine stores scalar values internally in higher precision than aggregate values.

### `Vector2<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>` (`Godot::Vector2`)

The `Godot::Vector2` type in GDScript corresponds to the *Godot Swift* type `Vector2<Float32>`. This type is a specialized `typealias` of the *Godot Swift* math library type `Vector<SIMD2<Float32>, Float32>`. You can learn more about the `Vector<Storage, Scalar>` type in the [math library reference](math-reference.md).

### `Vector3<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>` (`Godot::Vector3`)

The `Godot::Vector3` type in GDScript corresponds to the *Godot Swift* type `Vector3<Float32>`. This type is a specialized `typealias` of the *Godot Swift* math library type `Vector<SIMD3<Float32>, Float32>`. You can learn more about the `Vector<Storage, Scalar>` type in the [math library reference](math-reference.md).

### `Vector4<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>` (`Godot::Color`)

The `Godot::Color` type in GDScript corresponds to the *Godot Swift* type `Vector4<Float32>`. This type is a specialized `typealias` of the *Godot Swift* math library type `Vector<SIMD4<Float32>, Float32>`. You can learn more about the `Vector<Storage, Scalar>` type in the [math library reference](math-reference.md).

### `Quaternion<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>` (`Godot::Quat`)

The `Godot::Quat` type in GDScript corresponds to the *Godot Swift* type `Quaternion<Float32>`. You can learn more about the `Quaternion<T>` type in the [math library reference](math-reference.md).

> **Note:** The generic parameter of the `Quaternion<T>` has an additional type constraint requiring that `T:`[`Numerics.Real`](https://github.com/apple/swift-numerics/blob/main/Sources/RealModule/README.md).

### `Godot.Plane3<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>` (`Godot::Plane`)

The `Godot::Plane` type in GDScript corresponds to the *Godot Swift* type `Godot.Plane3<Float32>`.

Create a `Godot.Plane3<T>` instance from a normal vector and an origin point with the `init(normal:origin:)` initializer:

```swift 
let normal:Vector3<T>       = ... 
let origin:Vector3<T>       = ... 
let plane:Godot.Plane3<T>   = .init(normal: normal, origin: origin)
```

Access the normal vector and origin point through the properties `normal` and `origin`:

```swift 
let plane:Godot.Plane3<T>   = 
let normal:Vector3<T>       = plane.normal  
let origin:Vector3<T>       = plane.origin
```

You can convert between floating point precisions with the `init(_:)` initializer:

```swift 
let float64:Godot.Plane3<Float64> = ... 
let float32:Godot.Plane3<Float32> = .init(float64)
```

The `Godot.Plane3<T>` type is [`Hashable`](https://developer.apple.com/documentation/swift/hashable).

### `Godot.Transform2<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>.Affine` (`Godot::Transform2D`)

The `Godot::Transform2D` type in GDScript corresponds to the *Godot Swift* type `Godot.Transform2<Float32>.Affine`. It wraps the math library type `Vector2<Float32>.Matrix3`.

Create a `Godot.Transform2<T>.Affine` instance from column vectors `a`, `b`, `c` using the `init(matrix:)` initializer:

```swift 
let a:Vector2<T> = ... , 
    b:Vector2<T> = ... ,
    c:Vector2<T> = ... 
let transform:Godot.Transform2<T>.Affine = .init(matrix: (a, b, c))
```

Access the column vectors through the `matrix` property:

```swift 
let transform:Godot.Transform2<T>.Affine    = ...
let (a, b, c):Vector2<Float32>.Matrix3      = transform.matrix 
```

You can convert between floating point precisions with the `init(_:)` initializer:

```swift 
let float64:Godot.Transform2<Float64>.Affine = ... 
let float32:Godot.Transform2<Float32>.Affine = .init(float64)
```

The `Godot.Transform2<T>.Affine` type is [`Equatable`](https://developer.apple.com/documentation/swift/equatable).

### `Godot.Transform3<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>.Affine` (`Godot::Transform`)

The `Godot::Transform` type in GDScript corresponds to the *Godot Swift* type `Godot.Transform3<Float32>.Affine`. It wraps the math library type `Vector3<Float32>.Matrix4`.

Create a `Godot.Transform3<T>.Affine` instance from column vectors `a`, `b`, `c`, `d` using the `init(matrix:)` initializer:

```swift 
let a:Vector3<T> = ... , 
    b:Vector3<T> = ... ,
    c:Vector3<T> = ... ,
    d:Vector3<T> = ... 
let transform:Godot.Transform3<T>.Affine = .init(matrix: (a, b, c, d))
```

Access the column vectors through the `matrix` property:

```swift 
let transform:Godot.Transform3<T>.Affine    = ...
let (a, b, c, d):Vector3<Float32>.Matrix4   = transform.matrix 
```

You can convert between floating point precisions with the `init(_:)` initializer:

```swift 
let float64:Godot.Transform3<Float64>.Affine = ... 
let float32:Godot.Transform3<Float32>.Affine = .init(float64)
```

The `Godot.Transform3<T>.Affine` type is [`Equatable`](https://developer.apple.com/documentation/swift/equatable).

### `Godot.Transform3<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>.Linear` (`Godot::Basis`)

The `Godot::Basis` type in GDScript corresponds to the *Godot Swift* type `Godot.Transform3<Float32>.Linear`. It wraps the math library type `Vector3<Float32>.Matrix` (`Vector3<Float32>.Matrix3`).

Create a `Godot.Transform3<T>.Linear` instance from column vectors `a`, `b`, `c` using the `init(matrix:)` initializer:

```swift 
let a:Vector3<T> = ... , 
    b:Vector3<T> = ... ,
    c:Vector3<T> = ... 
let transform:Godot.Transform3<T>.Linear = .init(matrix: (a, b, c))
```

Access the column vectors through the `matrix` property:

```swift 
let transform:Godot.Transform3<T>.Linear    = ...
let (a, b, c):Vector3<Float32>.Matrix       = transform.matrix 
```

You can convert between floating point precisions with the `init(_:)` initializer:

```swift 
let float64:Godot.Transform3<Float64>.Linear = ... 
let float32:Godot.Transform3<Float32>.Linear = .init(float64)
```

The `Godot.Transform3<T>.Linear` type is [`Equatable`](https://developer.apple.com/documentation/swift/equatable).

## miscellaneous types

### `Godot.AnyDelegate` (`Godot::Object`)

The `Godot::Object` type in GDScript corresponds to the *Godot Swift* type `Godot.AnyDelegate`. In Swift, the term *object* refers exclusively to reference-counted values, so *Godot Swift* uses the term *delegate* to refer to what is otherwise known as an “object” elsewhere in the Godot world.

Reference-counted Godot delegates — that is, classes that inherit from `Godot::Reference` — correspond to the *Godot Swift* type `Godot.AnyObject`, which in turn, inherits from `Godot.AnyDelegate`.

> **Warning:** Do not confuse `Godot.AnyObject` with `Godot.AnyDelegate`. `Godot.AnyDelegate` is the root base class, not `Godot.AnyObject`.

Godot delegates are fully bridged to Swift’s dynamic type system. You can dynamically downcast to a subclass using the `as?` downcast operator.

```swift 
let delegate:Godot.AnyDelegate              = ... 
guard let mesh:Godot.Unmanaged.MeshInstance = delegate as? Godot.Unmanaged.MeshInstance 
else 
{
    ...
}
```

You can upcast to a superclass using the `as` upcast operator, just like any other Swift `class`. 

```swift 
let resource:Godot.Resource = ... 
let object:Godot.AnyObject  = resource as Godot.AnyObject
```

Emit a signal using the `emit(signal:as:)` method. It has the following signature: 

```swift 
final 
func emit<Signal>(signal value:Signal.Value, as _:Signal.Type)
    where Signal:Godot.Signal 
```

See the [using signals](README.md#using-signals) tutorial for more on how to use this method.

Almost all of the methods, properties, constants, and enumerations in the Godot engine API are available on the *Godot Swift* delegate classes. GDScript properties are exposed as computed Swift properties of the canonical variant type. Some properties allow you to avoid unnecessary type conversions by providing generic getter and setter methods. Generic getters are spelled `\(property name)(as:)`, and generic setters are spelled `set(\(property name):)`.

```swift 
let mesh:Godot.ArrayMesh = ... 

let float32:Vector3<Float32>.Rectangle = mesh.customAabb 
let float64:Vector3<Float64>.Rectangle = mesh.customAabb(as: Vector3<Float64>.Rectangle.self)
mesh.set(customAabb: float64)
```

Most GDScript methods are exposed as generic functions over appropriate type parameterizations. For example, all of the following are valid ways to call the `Godot.ArrayMesh.findByName(_:)` method:

```swift 
let mesh:Godot.ArrayMesh    = ... 
let godot:Godot.String      = ...
let swift:Swift.String      = ...

let index32:Int32   = mesh.surfaceFindByName(godot)
let index32:Int32   = mesh.surfaceFindByName(swift)
let index:Int       = mesh.surfaceFindByName(godot)
let index:Int       = mesh.surfaceFindByName(swift)
```

*Godot Swift* transforms all Godot symbol names (including argument labels) through a predefined set of string transformations, which convert Godot symbols to `camelCase` and expand unswifty abbreviations, among other things. You can find the full list of symbol transformation rules in the [symbol mappings reference](symbol-reference.md).

If you are unsure about the signature of a particular Godot API in *Godot Swift*, you can find the source code of the generated bindings, organized by delegate class name, in the `Sources/GodotNativeScriptGenerator/.gyb/classes/` directory. (These files are emitted by the plugin for your convenience, and are not actually the sources the plugin adds to your Swift library.)

Godot delegates are memory-managed by Swift. Keep in mind that this will only protect you from memory leaks if the delegate class itself is a memory-managed class (inherits from `Godot.AnyObject`). To help you keep track of this, all unmanaged Godot delegates are scoped under the namespace `Godot.Unmanaged`.

Use the `free()` method on `Godot.AnyDelegate` to manually deallocate an unmanaged delegate. [Use this with caution, just as in GDScript.](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free)

```swift 
let delegate:Godot.AnyDelegate = ... 
delegate.free()
```

> **Warning:** An instance of static type `Godot.AnyDelegate` may, of course, be an instance of `Godot.AnyObject`, or one of its subclasses. Make sure an delegate of static type `Godot.AnyDelegate` is actually an unmanaged delegate before manually deallocating it.

### `Godot.NodePath` (`Godot::NodePath`)

The `Godot::NodePath` type in GDScript corresponds to the *Godot Swift* type `Godot.NodePath`.

Create a `Godot.NodePath` instance from a string using the `init(parsing:)` initializer.

```swift 
let string:Swift.String = ...
let path:Godot.NodePath = .init(parsing: string)
```

Instances of `Godot.NodePath` are memory-managed by Swift.

### `Godot.ResourceIdentifier` (`Godot::RID`)

The `Godot::RID` type in GDScript corresponds to the *Godot Swift* type `Godot.ResourceIdentifier`.

Create a `Godot.ResourceIdentifier` from a raw `Int` bit-pattern using the `init(bitPattern:)` initializer. Only use this if you really know what you are doing.

```swift 
let bits:Int = ...
let rid:Godot.ResourceIdentifier = .init(bitPattern: bits)
```

> **Warning:** Godot resource identifiers are semantically similar to opaque pointers, and resource identifiers with invalid bit-patterns may cause runtime crashes.

The `Godot.ResourceIdentifier` type is a trivial type, and therefore does not require memory management.

## array types 

Pooled arrays in GDScript are represented in *Godot Swift* as specializations of `Godot.Array<Element>`.

The `Godot.Array<Element>` type is an opaque wrapper around a Godot pooled array, and it supports no functionality other than converting to and from a native Swift `Array`. The main purpose of this type is to allow arrays and variant existentials to be moved without copying the underlying array buffer, in situations where it is not necessary to interact with the actual contents of the array. It can be thought of as a generalization of `Godot.String`. (However, it has no direct type-system relationship to the `Godot.String` type.)

You can convert between Godot arrays and native Swift arrays using the `init(_:)` initializers on each type.

```swift 
let array:[Element]             = ... 

let godot:Godot.Array<Element>  = .init(array)
let swift:[Element]             = .init(godot)
```

All Godot engine APIs that take pooled array arguments can also take native Swift arrays, so it is rarely necessary to directly create instances of `Godot.Array<Element>`.

Instances of `Godot.Array<Element>` are memory-managed by Swift.

### `Godot.Array<`[`UInt8`](https://developer.apple.com/documentation/swift/uint8)`>` (`Godot::PoolByteArray`)

The `Godot::PoolByteArray` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<UInt8>`.

### `Godot.Array<`[`Int32`](https://developer.apple.com/documentation/swift/int32)`>` (`Godot::PoolIntArray`)

The `Godot::PoolIntArray` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<Int32>`.

### `Godot.Array<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>` (`Godot::PoolRealArray`)

The `Godot::PoolRealArray` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<Float32>`.

### `Godot.Array<Vector2<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>>` (`Godot::PoolVector2Array`)

The `Godot::PoolVector2Array` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<Vector2<Float32>>`.

### `Godot.Array<Vector3<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>>` (`Godot::PoolVector3Array`)

The `Godot::PoolVector3Array` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<Vector3<Float32>>`.

### `Godot.Array<Vector4<`[`Float32`](https://developer.apple.com/documentation/swift/float)`>>` (`Godot::PoolColorArray`)

The `Godot::PoolColorArray` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<Vector4<Float32>>`.

### `Godot.Array<`[`String`](https://developer.apple.com/documentation/swift/string)`>` (`Godot::PoolStringArray`)

The `Godot::PoolStringArray` type in GDScript corresponds to the *Godot Swift* type `Godot.Array<String>`. Note that the element type is the native Swift `String` type, *not* `Godot.String`.

## variant-representable types

Most GDScript types can be seamlessly bridged to multiple Swift types, through the `Godot.VariantRepresentable` protocol.

### integer-representable types

Most of Swift’s built-in integer types are representable by `Godot::int`. In particular, you can use: 

1. [`Int32`](https://developer.apple.com/documentation/swift/Int32)
2. [`Int16`](https://developer.apple.com/documentation/swift/Int16)
3. [`Int8`](https://developer.apple.com/documentation/swift/Int8)
4. [`Int`](https://developer.apple.com/documentation/swift/Int)


5. [`UInt64`](https://developer.apple.com/documentation/swift/UInt64)
6. [`UInt32`](https://developer.apple.com/documentation/swift/UInt32)
7. [`UInt16`](https://developer.apple.com/documentation/swift/UInt16)
8. [`UInt8`](https://developer.apple.com/documentation/swift/UInt8)
9. [`UInt`](https://developer.apple.com/documentation/swift/UInt)

Note that `Int64` is a `Godot.Variant` type, which means it is already `Godot.VariantRepresentable`.

The numeric conversion will only succeed if the GDScript integer value does not overflow the specified Swift type. Otherwise, a runtime error will occur.

### float-representable types

Most of Swift’s built-in floating point types are representable by `Godot::float`. In particular, you can use: 

1. [`Float32`](https://developer.apple.com/documentation/swift/Float)
2. [`Float16`](https://developer.apple.com/documentation/swift/Float16)

Note that `Float64` (`Double`) is a `Godot.Variant` type, which means it is already `Godot.VariantRepresentable`.

The numeric conversion always succeeds, but may lose precision.

### vector-representable types

The *Godot Swift* math library vector types are conditionally representable by `Godot::Vector2`, `Godot::Vector3`, or `Godot::Color`, depending on their arity and scalar type. In particular, you can use: 

1. `Vector2<Float64>` (from `Godot::Vector2`)
2. `Vector2<Float16>` (from `Godot::Vector2`)


3. `Vector3<Float64>` (from `Godot::Vector3`)
4. `Vector3<Float16>` (from `Godot::Vector3`)


5. `Vector4<Float64>` (from `Godot::Color`)
6. `Vector4<Float16>` (from `Godot::Color`)

Note that `Vector2<Float32>`, `Vector3<Float32>`, and `Vector4<Float32>` are `Godot.Variant` types, which means they are already `Godot.VariantRepresentable`.

The numeric conversion always succeeds, but may lose precision.

### rectangle-representable types

The *Godot Swift* math library rectangle types are conditionally representable by `Godot::Rect2`, or `Godot::AABB`, depending on their arity and scalar type. In particular, you can use: 

1. `Vector2<Float64>.Rectangle` (from `Godot::Rect2`)
2. `Vector2<Float16>.Rectangle` (from `Godot::Rect2`)
3. `Vector2<Float64>.ClosedRectangle` (from `Godot::Rect2`)
4. `Vector2<Float32>.ClosedRectangle` (from `Godot::Rect2`)
5. `Vector2<Float16>.ClosedRectangle` (from `Godot::Rect2`)


1. `Vector3<Float64>.Rectangle` (from `Godot::AABB`)
2. `Vector3<Float16>.Rectangle` (from `Godot::AABB`)
3. `Vector3<Float64>.ClosedRectangle` (from `Godot::AABB`)
4. `Vector3<Float32>.ClosedRectangle` (from `Godot::AABB`)
5. `Vector3<Float16>.ClosedRectangle` (from `Godot::AABB`)

Note that `Vector2<Float32>.Rectangle`, and `Vector3<Float32>.Rectangle` are `Godot.Variant` types, which means they are already `Godot.VariantRepresentable`.

The numeric conversion always succeeds, but may lose precision.

### other variant-representable math types 

The remaining *Godot Swift* math types are always `Godot.VariantRepresentable`, for any of their generic specializations:

1. `Quaternion<T>` (from `Godot::Quat`)
2. `Godot.Plane3<T>` (from `Godot::Plane`)
3. `Godot.Transform2<T>.Affine` (from `Godot::Transform2D`)
4. `Godot.Transform3<T>.Affine` (from `Godot::Transform`)
5. `Godot.Transform3<T>.Linear` (from `Godot::Basis`)

### string-representable types 

As previously mentioned, Swift’s native `String` type is representable by `Godot::String`. 

1. `Swift.String`

### array-representable types 

As previously mentioned, Swift’s native `Array` is representable by `Godot::PoolByteArray`, `Godot::PoolIntArray`, `Godot::PoolRealArray`, `Godot::PoolVector2Array`, `Godot::PoolVector3Array`, `Godot::PoolColorArray`, or `Godot::PoolStringArray`, as long as its `Element` type is the appropriate Godot pooled array element type.

1. `[UInt8]` (from `Godot::PoolByteArray`)
2. `[Int32]` (from `Godot::PoolIntArray`)
3. `[Float32]` (from `Godot::PoolRealArray`)
4. `[Vector2<Float32>]` (from `Godot::PoolVector2Array`)
5. `[Vector3<Float32>]` (from `Godot::PoolVector3Array`)
6. `[Vector4<Float32>]` (from `Godot::PoolColorArray`)
7. `[Swift.String]` (from `Godot::PoolStringArray`)

### optional types 

Any `Optional<Wrapped>` type is `Godot.VariantRepresentable` if its `Wrapped` type is `Godot.VariantRepresentable`. If so, the optional type is representable by the union type of `Godot::null` and the GDScript type that `Wrapped` is representable by.

1. [`Optional<Wrapped>`](https://developer.apple.com/documentation/swift/Optional) `where Wrapped:Godot.VariantRepresentable`
