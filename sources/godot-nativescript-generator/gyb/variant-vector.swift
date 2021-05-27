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
        for n:Int in 2 ... 3 
        {
            """
            extension SIMD\(n):Godot.RectangleStorage where Scalar:Godot.RectangleElement
            {
                typealias RectangleAggregate = Scalar.Rectangle\(n)Aggregate
            }
            """
        }
        for type:String in ["Float16", "Float32", "Float64"] 
        {
            "extension \(type):Godot.VectorElement {}"
        }
        """
        extension Vector:Godot.VariantRepresentable 
            where Storage:Godot.VectorStorage
        {
            static 
            var variantType:Godot.VariantType 
            {
                Storage.VectorAggregate.variantType
            }
            static 
            func takeUnretained(_ value:Godot.Unmanaged.Variant) -> Self?
            {
                Storage.VectorAggregate.unpacked(variant: value).map(Storage.generalize(_:))
            }
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
