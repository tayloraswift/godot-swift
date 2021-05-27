enum VariantArray 
{
    @Source.Code 
    static 
    var swift:String 
    {
        """
        extension Godot 
        {
            typealias ArrayElement          = _GodotArrayElement
            typealias ArrayElementStorage   = _GodotArrayElementStorage // needed for vectors
        }
        /// protocol Godot.ArrayElement 
        ///     A type that can be used as an [`Godot.Array.Element`] type.
        /// 
        ///     Do not conform additional types to this protocol.
        /// #   (godot-core-protocols)
        protocol _GodotArrayElement 
        {
            /// associatedtype Godot.ArrayElement.RawArrayReference 
            /// where RawArrayReference:Godot.RawReference
            associatedtype RawArrayReference:Godot.RawReference
            
            static 
            func downcast(array:Godot.Unmanaged.Variant) -> RawArrayReference?
            static 
            func upcast(array:RawArrayReference) -> Godot.Unmanaged.Variant
            static 
            func convert(array godot:RawArrayReference) -> [Self]
            static 
            func convert(array swift:[Self]) -> RawArrayReference
        }
        /// protocol Godot.ArrayElementStorage 
        /// :   SIMD 
        ///     A type that can be used as vector backing storage for a [`Godot.Array.Element`] type.
        /// #   (godot-core-protocols)
        protocol _GodotArrayElementStorage:SIMD where Scalar:SIMDScalar
        {
            /// associatedtype Godot.ArrayElementStorage.RawArrayReference 
            /// where RawArrayReference:Godot.RawReference
            associatedtype RawArrayReference:Godot.RawReference
            
            static 
            func downcast(array:Godot.Unmanaged.Variant) -> RawArrayReference?
            static 
            func upcast(array:RawArrayReference) -> Godot.Unmanaged.Variant
            static 
            func convert(array godot:RawArrayReference) -> [Vector<Self, Scalar>]
            static 
            func convert(array swift:[Vector<Self, Scalar>]) -> RawArrayReference
        }
        """
        // generate variant hooks for pool arrays 
        for (swift, godot, array, storage):(String, String?, String, String?) in 
        [
            ("UInt8",                   nil,                "pool_byte_array",      nil),
            ("Int32",                   nil,                "pool_int_array",       nil),
            ("Float32",                 nil,                "pool_real_array",      nil),
            ("String",                  "godot_string",     "pool_string_array",    nil),
            ("Vector<Self, Scalar>",    "godot_vector2",    "pool_vector2_array",   "SIMD2"),
            ("Vector<Self, Scalar>",    "godot_vector3",    "pool_vector3_array",   "SIMD3"),
            ("Vector<Self, Scalar>",    "godot_color",      "pool_color_array",     "SIMD4"),
        ]
        {
            let type:String = storage == nil ? "Self" : swift
            if let storage:String = storage 
            {
                """
                /// extension \(storage) 
                /// :   Godot.ArrayElementStorage 
                /// where Scalar == Float32
                extension \(storage):Godot.ArrayElementStorage where Scalar == Float32
                """
            }
            else 
            {
                """
                /// extension \(swift)
                /// :   Godot.ArrayElement
                extension \(swift):Godot.ArrayElement
                """
            }
            Source.block 
            {
                """
                typealias RawArrayReference = godot_\(array)
                
                static 
                func downcast(array value:Godot.Unmanaged.Variant) -> RawArrayReference?
                {
                    value.load(where: RawArrayReference.variantType, 
                        Godot.api.1.0.godot_variant_as_\(array))
                }
                static 
                func upcast(array value:RawArrayReference) -> Godot.Unmanaged.Variant
                {
                    withUnsafePointer(to: value) 
                    {
                        .init(value: $0, Godot.api.1.0.godot_variant_new_\(array))
                    }
                }
                static 
                func convert(array godot:RawArrayReference) -> [\(type)]
                """
                Source.block
                {
                    """
                    guard let lock:UnsafeMutablePointer<godot_\(array)_read_access> = 
                        withUnsafePointer(to: godot, Godot.api.1.0.godot_\(array)_read)
                    else 
                    {
                        fatalError("received nil pointer from `godot_\(array)_read(_:)`")
                    }
                    defer 
                    {
                        Godot.api.1.0.godot_\(array)_read_access_destroy(lock)
                    }
                    let count:Int = .init(
                        withUnsafePointer(to: godot, Godot.api.1.0.godot_\(array)_size))
                    return .init(unsafeUninitializedCapacity: count) 
                    """
                    Source.block
                    {
                        """
                        guard let source:UnsafePointer<\(godot ?? "Self")> = 
                            Godot.api.1.0.godot_\(array)_read_access_ptr(lock)
                        else 
                        {
                            fatalError("received nil pointer from `godot_\(array)_read_access_ptr(_:)`")
                        }
                        """
                        if let _:String = godot
                        {
                            """
                            if let base:UnsafeMutablePointer<\(type)> = $0.baseAddress 
                            {
                                for i:Int in 0 ..< count 
                                {
                                    (base + i).initialize(to: source[i].unpacked)
                                }
                            }
                            """
                        }
                        else 
                        {
                            """
                            $0.baseAddress?.initialize(from: source, count: count)
                            """
                        }
                        """
                        $1 = count 
                        """
                    }
                }
                """
                static 
                func convert(array swift:[\(type)]) -> RawArrayReference
                """
                Source.block 
                {
                    """
                    var array:godot_\(array) = .init(with: Godot.api.1.0.godot_\(array)_new)
                    Godot.api.1.0.godot_\(array)_resize(&array, .init(swift.count))
                    
                    guard let lock:UnsafeMutablePointer<godot_\(array)_write_access> = 
                        Godot.api.1.0.godot_\(array)_write(&array)
                    else 
                    {
                        fatalError("received nil pointer from `godot_\(array)_write(_:)`")
                    }
                    defer 
                    {
                        Godot.api.1.0.godot_\(array)_write_access_destroy(lock)
                    }
                    
                    guard let destination:UnsafeMutablePointer<\(godot ?? "Self")> = 
                        Godot.api.1.0.godot_\(array)_write_access_ptr(lock)
                    else 
                    {
                        fatalError("received nil pointer from `godot_\(array)_write_access_ptr(_:)`")
                    }
                    """
                    if let _:String = godot
                    {
                        "for (i, element):(Int, \(type)) in swift.enumerated()"
                        Source.block
                        {
                            if swift == "String" 
                            {
                                "destination[i].deinit() // is this needed?"
                            }
                            "destination[i] = .init(packing: element)"
                        }
                    }
                    else 
                    {
                        """
                        swift.withUnsafeBufferPointer 
                        {
                            guard let base:UnsafePointer<Self> = $0.baseAddress
                            else 
                            {
                                return 
                            }
                            destination.initialize(from: base, count: swift.count)
                        }
                        """
                    }
                    """
                    return array
                    """
                }
            }
        }
        """
        extension Vector:Godot.ArrayElement where Storage:Godot.ArrayElementStorage 
        {
            /// typealias Vector.RawArrayReference = Storage.RawArrayReference 
            /// ?:  Godot.ArrayElement where Storage:Godot.ArrayElementStorage 
            typealias RawArrayReference = Storage.RawArrayReference
            
            static 
            func downcast(array value:Godot.Unmanaged.Variant) -> RawArrayReference?
            {
                Storage.downcast(array: value)
            }
            static 
            func upcast(array value:RawArrayReference) -> Godot.Unmanaged.Variant
            {
                Storage.upcast(array: value)
            }
            static 
            func convert(array godot:RawArrayReference) -> [Self]
            {
                Storage.convert(array: godot)
            }
            static 
            func convert(array swift:[Self]) -> RawArrayReference
            {
                Storage.convert(array: swift)
            }
        }
        
        /// class Godot.Array<Element>
        /// :   Godot.Variant 
        /// where Element:Godot.ArrayElement
        /// final 
        ///     One of the Godot pooled array types.
        /// 
        ///     This type is automatically memory-managed by Swift.
        /// 
        ///     **Warning:** Godot pooled arrays have copy-on-write semantics 
        ///     in GDScript. Mutating a pooled array in GDScript will unlink it 
        ///     from any instances of this Swift class that hold a reference to 
        ///     it. 
        /// 
        ///     **Note:** This type may become a `struct` in the future, in order 
        ///     to support proper copy-on-write semantics. To prevent source 
        ///     breakage, this type does not currently support any functionality 
        ///     that would modify the underlying array. This ensures that all 
        ///     available *Godot Swift* APIs are semantically safe to use.
        """
        for (godot, element):(String, String) in 
        [
            ("String",  "Swift.String"), // `String` shadowed by `Godot.String`
            ("Byte",    "UInt8"),
            ("Int",     "Int32"),
            ("Real",    "Float32"),
            ("Vector2", "Vector2<Float32>"),
            ("Vector3", "Vector3<Float32>"),
            ("Color",   "Vector4<Float32>"),
        ]
        {
            """
            /// 
            ///     If [`Element`] is [[`\(element)`]], this type corresponds to the 
            ///     [`Godot::Pool\(godot)Array`](https://docs.godotengine.org/en/stable/classes/class_pool\(godot.lowercased())array.html) type.
            """
        }
        """
        /// #   (11:godot-core-types)
        extension Godot 
        {
            final 
            class Array<Element> where Element:ArrayElement 
            {
                // needs to be fileprivate so Swift.Array.init(_:) can access it
                fileprivate private(set)
                var core:Element.RawArrayReference 
                
                fileprivate 
                init(retained core:Element.RawArrayReference) 
                {
                    self.core = core
                }
                
                private 
                init(with initializer:(UnsafeMutablePointer<Element.RawArrayReference>) -> ()) 
                {
                    self.core = .init(with: initializer)
                }
                
                deinit 
                {
                    self.core.deinit()
                }
            } 
        }
        
        extension Godot.Array:Godot.Variant 
        {
            /// static var Godot.Array.variantType:Godot.VariantType { get }
            /// ?:  Godot.VariantRepresentable 
            static 
            var variantType:Godot.VariantType 
            {
                Element.RawArrayReference.variantType
            }
            
            /// static func Godot.Array.takeUnretained(_:)
            /// ?:  Godot.VariantRepresentable 
            ///     Attempts to load a pooled array instance from a variant value.
            /// 
            ///     This function does not (immediately) deep-copy the array storage. 
            ///     However, because Godot pooled arrays have copy-on-write semantics,
            ///     modifications to the original pooled array in GDScript will 
            ///     not be reflected in the returned Swift instance.
            /// - value :Godot.Unmanaged.Variant 
            /// - ->    :Self? 
            static 
            func takeUnretained(_ value:Godot.Unmanaged.Variant) -> Self?
            {
                Element.downcast(array: value).map(Self.init(retained:))
            }
            /// func Godot.Array.passRetained()
            /// ?:  Godot.VariantRepresentable 
            ///     Stores this pooled array instance as a variant value.
            /// 
            ///     This function does not (immediately) deep-copy the array storage. 
            ///     However, because Godot pooled arrays have copy-on-write semantics,
            ///     modifications to the returned array in GDScript will not  
            ///     be reflected in the original instance of `self`.
            /// - ->    :Godot.Unmanaged.Variant 
            func passRetained() -> Godot.Unmanaged.Variant 
            {
                withExtendedLifetime(self)
                {
                    Element.upcast(array: self.core)
                }
            }
        }
        
        extension Godot.Array 
        {
            /// init Godot.Array.init(_:)
            ///     Converts a native Swift array to a Godot pooled array.
            /// - swift:[Element]
            ///     A native Swift array.
            convenience
            init(_ swift:[Element]) 
            {
                self.init(retained: Element.convert(array: swift))
            }
        }
        /// extension Array 
        /// :   Godot.VariantRepresentable 
        /// where Element:Godot.ArrayElement 
        extension Array:Godot.VariantRepresentable 
            where Element:Godot.ArrayElement 
        {
            /// init Array.init(_:)
            ///     Converts a Godot pooled array to a native Swift array.
            /// - godot:Godot.Array<Element>
            ///     A Godot pooled array.
            init(_ godot:Godot.Array<Element>) 
            {
                self = withExtendedLifetime(godot) 
                {
                    Element.convert(array: godot.core)
                }
            }
            
            /// static var Array.variantType:Godot.VariantType { get }
            /// ?:  Godot.VariantRepresentable 
            static 
            var variantType:Godot.VariantType 
            {
                Element.RawArrayReference.variantType
            }
            /// static func Array.takeUnretained(_:)
            /// ?:  Godot.VariantRepresentable 
            ///     Attempts to load a Swift array from a variant value.
            /// 
            ///     This function deep-copies the pooled array’s storage. The 
            ///     returned Swift array is completely independent of the original 
            ///     pooled array instance.
            /// - value :Godot.Unmanaged.Variant 
            /// - ->    :Self? 
            static 
            func takeUnretained(_ value:Godot.Unmanaged.Variant) -> Self?
            {
                value.take(unretained: Godot.Array<Element>.self).map(Self.init(_:))
            }
            /// func Array.passRetained()
            /// ?:  Godot.VariantRepresentable 
            ///     Stores this Swift array as a variant value.
            /// 
            ///     This function deep-copies this array’s storage. The 
            ///     returned variant value is completely independent of the original 
            ///     Swift array.
            /// - ->    :Godot.Unmanaged.Variant 
            func passRetained() -> Godot.Unmanaged.Variant 
            {
                .pass(retaining: Godot.Array<Element>.init(self))
            }
        }
        """
    }
}
