enum VariantRepresentations 
{
    @Source.Code 
    static 
    var swift:String 
    {
        // raw values 
        """
        extension Godot 
        {
            typealias RawValue      = _GodotRawValue
            typealias RawReference  = _GodotRawReference 
        }
        /// protocol Godot.RawValue 
        ///     A trivial GDScript type.
        /// 
        ///     Do not conform additional types to this protocol.
        /// #   (-2:godot-generic-unification-protocols)
        protocol _GodotRawValue
        {
            init()
            
            static 
            var variantType:Godot.VariantType 
            {
                get 
            }
        }
        extension Godot.RawValue 
        {
            init(with initializer:(UnsafeMutablePointer<Self>) -> ()) 
            {
                self.init()
                initializer(&self)
            }
        }

        /// protocol Godot.RawReference
        /// :   Godot.RawValue 
        ///     A non-trivial GDScript type.
        /// 
        ///     Do not conform additional types to this protocol.
        /// #   (-1:godot-generic-unification-protocols)
        protocol _GodotRawReference:Godot.RawValue
        {
            mutating
            func `deinit`()
        }
        """
        for (name, type, unpacked):(String, String, String) in 
        [
            ("vector2",         "vector2",              "Vector2<Float32>"), 
            ("vector3",         "vector3",              "Vector3<Float32>"), 
            ("color",           "vector4",              "Vector4<Float32>"), 
            ("quat",            "quaternion",           "Quaternion<Float32>"), 
            ("rect2",           "rectangle2",           "Vector2<Float32>.Rectangle"), 
            ("aabb",            "rectangle3",           "Vector3<Float32>.Rectangle"), 
            ("plane",           "plane3",               "Vector3<Float32>.Plane"), 
            ("transform2d",     "affine2",              "Godot.Transform2<Float32>.Affine"), 
            ("transform",       "affine3",              "Godot.Transform3<Float32>.Affine"), 
            ("basis",           "linear3",              "Godot.Transform3<Float32>.Linear"), 
            ("rid",             "resourceIdentifier",   "Godot.ResourceIdentifier"), 
        ]
        {
            """
            extension godot_\(name):Godot.RawValue 
            {
                static 
                var variantType:Godot.VariantType 
                {
                    .\(type)
                }
                static 
                func unpacked(variant:Godot.Unmanaged.Variant) -> \(unpacked)? 
                {
                    variant.load(where: Self.variantType)
                    {
                        Godot.api.1.0.godot_variant_as_\(name)($0).unpacked
                    } 
                }
                static 
                func variant(packing value:\(unpacked)) -> Godot.Unmanaged.Variant
                {
                    withUnsafePointer(to: Self.init(packing: value)) 
                    {
                        .init(value: $0, Godot.api.1.0.godot_variant_new_\(name))
                    }
                }
            }
            """
        }
        for (name, type):(String, String) in 
        [
            ("node_path",           "nodePath"), 
            ("string",              "string"), 
            ("array",               "list"), 
            ("dictionary",          "map"), 
            ("pool_byte_array",     "uint8Array"), 
            ("pool_int_array",      "int32Array"),
            ("pool_real_array",     "float32Array"),
            ("pool_string_array",   "stringArray"),
            ("pool_vector2_array",  "vector2Array"),
            ("pool_vector3_array",  "vector3Array"),
            ("pool_color_array",    "vector4Array"),
        ]
        {
            """
            extension godot_\(name):Godot.RawReference
            {
                mutating 
                func `deinit`()
                {
                    Godot.api.1.0.godot_\(name)_destroy(&self)
                }
                
                static 
                var variantType:Godot.VariantType 
                {
                    .\(type)
                }
            }
            """
        }
        
        // vector conformances 
        """
        // huge amount of meaningless boilerplate needed to make numeric conversions work, 
        // since swift does not support generic associated types.
        extension Godot 
        {
            typealias VectorElement     = _GodotVectorElement
            typealias VectorStorage     = _GodotVectorStorage
        }
        /// protocol Godot.VectorElement 
        /// :   SIMDScalar 
        ///     A unification protocol providing support for converting qualifying 
        ///     instances of [`Vector`] to and from their GDScript representations.
        /// 
        ///     All types conforming to [`BinaryFloatingPoint`] support the 
        ///     functionality required to conform to this protocol. 
        /// 
        ///     Conformances for [`Float16`], [`Float32`], and [`Float64`] have 
        ///     already been provided. You can add support for additional 
        ///     [`BinaryFloatingPoint`] types by explicitly declaring the conformance 
        ///     in user code.
        /// #   (12:godot-generic-unification-protocols)
        protocol _GodotVectorElement:SIMDScalar 
        """
        Source.block 
        {
            for n:Int in 2 ... 4 
            {
                "associatedtype Vector\(n)Aggregate:Godot.RawAggregate"
            }
            for n:Int in 2 ... 4 
            {
                """
                static 
                func generalize(_ specific:Vector\(n)Aggregate.Unpacked) -> Vector\(n)<Self> 
                """
            }
            for n:Int in 2 ... 4 
            {
                """
                static 
                func specialize(_ general:Vector\(n)<Self>) -> Vector\(n)Aggregate.Unpacked 
                """
            }
        }
        """
        /// protocol Godot.VectorStorage 
        /// :   SIMD
        ///     A unification protocol providing support for converting qualifying 
        ///     instances of [[`Vector`]] to and from their GDScript representations.
        /// #   (2:godot-generic-unification-protocols)
        protocol _GodotVectorStorage:SIMD where Scalar:SIMDScalar 
        {
            associatedtype VectorAggregate:Godot.RawAggregate
            
            static 
            func generalize(_ specific:VectorAggregate.Unpacked) -> Vector<Self, Scalar> 
            static 
            func specialize(_ general:Vector<Self, Scalar>) -> VectorAggregate.Unpacked 
        }

        // need to work around type system limitations
        extension BinaryFloatingPoint where Self:SIMDScalar
        """
        Source.block 
        {
            """
            typealias Vector2Aggregate = godot_vector2
            typealias Vector3Aggregate = godot_vector3
            typealias Vector4Aggregate = godot_color
            
            """
            for n:Int in 2 ... 4 
            {
                """
                static 
                func generalize(_ specific:Vector\(n)<Float32>) -> Vector\(n)<Self> 
                {
                    .init(specific)
                }
                """
            }
            for n:Int in 2 ... 4 
            {
                """
                static 
                func specialize(_ general:Vector\(n)<Self>) -> Vector\(n)<Float32> 
                {
                    .init(general)
                }
                """
            }
        }
        for n:Int in 2 ... 4 
        {
            """
            /// extension SIMD\(n)
            /// :   Godot.VectorStorage 
            /// where Scalar:Godot.VectorElement
            extension SIMD\(n):Godot.VectorStorage where Scalar:Godot.VectorElement
            {
                typealias VectorAggregate = Scalar.Vector\(n)Aggregate
                static 
                func generalize(_ specific:VectorAggregate.Unpacked) -> Vector\(n)<Scalar> 
                {
                    Scalar.generalize(specific)
                }
                static 
                func specialize(_ general:Vector\(n)<Scalar>) -> VectorAggregate.Unpacked
                {
                    Scalar.specialize(general)
                }
            }
            """
        }
        // already provided for by Godot.RectangleElement conformances
        /* for type:String in ["Float16", "Float32", "Float64"] 
        {
            """
            /// extension \(type)
            /// :   Godot.VectorElement
            extension \(type):Godot.VectorElement {}
            """
        } */
        // rectangle conformances
        """
        // huge amount of meaningless boilerplate needed to make numeric conversions work, 
        // since swift does not support generic associated types.
        extension Godot 
        {
            typealias RectangleElement  = _GodotRectangleElement
            typealias RectangleStorage  = _GodotRectangleStorage
        }
        /// protocol Godot.RectangleElement 
        /// :   Godot.VectorElement
        ///     A unification protocol providing support for converting qualifying 
        ///     instances of [`Vector.Rectangle`] and [`Vector.ClosedRectangle`] 
        ///     to and from their GDScript representations.
        /// 
        ///     All types conforming to [`BinaryFloatingPoint`] support the 
        ///     functionality required to conform to this protocol. 
        /// 
        ///     Conformances for [`Float16`], [`Float32`], and [`Float64`] have 
        ///     already been provided. You can add support for additional 
        ///     [`BinaryFloatingPoint`] types by explicitly declaring the conformance 
        ///     in user code.
        /// #   (11:godot-generic-unification-protocols)
        protocol _GodotRectangleElement:Godot.VectorElement 
        """
        Source.block 
        {
            for n:Int in 2 ... 3 
            {
                """
                associatedtype Rectangle\(n)Aggregate:Godot.RawAggregate
                    where   Rectangle\(n)Aggregate.Unpacked:VectorFiniteRangeExpression, 
                            Rectangle\(n)Aggregate.Unpacked.Bound == Vector\(n)Aggregate.Unpacked
                """
            }
        }
        """
        /// protocol Godot.RectangleStorage 
        /// :   Godot.VectorStorage
        ///     A unification protocol providing support for converting qualifying 
        ///     instances of [`Vector.Rectangle`] and [`Vector.ClosedRectangle`] 
        ///     to and from their GDScript representations.
        /// 
        ///     All types conforming to [`VectorFiniteRangeExpression`] support the 
        ///     functionality required to conform to [`Godot.VariantRepresentable`], 
        ///     as long as [`(VectorFiniteRangeExpression).Storage`] conforms 
        ///     to this protocol.
        /// 
        ///     Conditional conformances to [`Godot.VariantRepresentable`] 
        ///     have already been provided for [`Vector.Rectangle`] and 
        ///     [`Vector.ClosedRectangle`]. You can add support for additional 
        ///     [`VectorFiniteRangeExpression`] types by explicitly declaring the 
        ///     conformance to [`Godot.VariantRepresentable`] in user code.
        /// #   (1:godot-generic-unification-protocols)
        protocol _GodotRectangleStorage:Godot.VectorStorage 
        {
            associatedtype RectangleAggregate:Godot.RawAggregate
                where   RectangleAggregate.Unpacked:VectorFiniteRangeExpression, 
                        RectangleAggregate.Unpacked.Bound == VectorAggregate.Unpacked
        }
        // need to work around type system limitations
        extension BinaryFloatingPoint where Self:SIMDScalar
        {
            typealias Rectangle2Aggregate = godot_rect2
            typealias Rectangle3Aggregate = godot_aabb
        }
        """
        for n:Int in 2 ... 3 
        {
            """
            /// extension SIMD\(n)
            /// :   Godot.RectangleStorage 
            /// where Scalar:Godot.RectangleElement
            extension SIMD\(n):Godot.RectangleStorage where Scalar:Godot.RectangleElement
            {
                typealias RectangleAggregate = Scalar.Rectangle\(n)Aggregate
            }
            """
        }
        for type:String in ["Float16", "Float32", "Float64"] 
        {
            """
            /// extension \(type)
            /// :   Godot.RectangleElement
            extension \(type):Godot.RectangleElement {}
            """
        }
    }
}
