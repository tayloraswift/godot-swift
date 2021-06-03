enum VariantVector
{
    @Source.Code 
    static 
    var swift:String 
    {
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
        """
        extension Vector:Godot.VariantRepresentable 
            where Storage:Godot.VectorStorage
        {
            /// static var Vector.variantType:Godot.VariantType { get }
            /// ?:  Godot.VariantRepresentable where Storage:Godot.VectorStorage
            static 
            var variantType:Godot.VariantType 
            {
                Storage.VectorAggregate.variantType
            }
            /// static func Vector.takeUnretained(_:)
            /// ?:  Godot.VariantRepresentable where Storage:Godot.VectorStorage
            /// - value :Godot.Unmanaged.Variant 
            /// - ->    :Self? 
            static 
            func takeUnretained(_ value:Godot.Unmanaged.Variant) -> Self?
            {
                Storage.VectorAggregate.unpacked(variant: value).map(Storage.generalize(_:))
            }
            /// func Vector.passRetained()
            /// ?:  Godot.VariantRepresentable where Storage:Godot.VectorStorage
            /// - ->    :Godot.Unmanaged.Variant 
            func passRetained() -> Godot.Unmanaged.Variant 
            {
                Storage.VectorAggregate.variant(packing: Storage.specialize(self))
            }
        }
        extension Vector:Godot.Variant where Storage:Godot.VectorStorage, T == Float32 
        {
        }
        """
    }
}
