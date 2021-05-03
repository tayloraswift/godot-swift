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

The concrete *Godot Swift* types are detailed in the next section.

## concrete types 

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

The `Godot.String` type is an opaque wrapper around a `Godot::String` object, and it supports no functionality other than converting to and from a native Swift `String`. The main purpose of this type is to allow strings and variant existentials to be moved and copied without copying the underlying string buffer, in situations where it is not necessary to interact with the actual contents of the string.

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
