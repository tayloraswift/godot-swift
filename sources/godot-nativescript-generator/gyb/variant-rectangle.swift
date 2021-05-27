enum VariantRectangle
{
    @Source.Code 
    static 
    var swift:String 
    {
        """
        // huge amount of meaningless boilerplate needed to make numeric conversions work, 
        // since swift does not support generic associated types.
        extension Godot 
        {
            typealias RectangleElement  = _GodotRectangleElement
            typealias RectangleStorage  = _GodotRectangleStorage
        }
        
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
            extension SIMD\(n):Godot.RectangleStorage where Scalar:Godot.RectangleElement
            {
                typealias RectangleAggregate = Scalar.Rectangle\(n)Aggregate
            }
            """
        }
        for type:String in ["Float16", "Float32", "Float64"] 
        {
            "extension \(type):Godot.RectangleElement {}"
        }
        """
        extension VectorFiniteRangeExpression where Storage:Godot.RectangleStorage 
        {
            static 
            var variantType:Godot.VariantType 
            {
                Storage.RectangleAggregate.variantType
            }
            static 
            func takeUnretained(_ value:Godot.Unmanaged.Variant) -> Self?
            {
                Storage.RectangleAggregate.unpacked(variant: value).map
                {
                    return Self.init(
                        lowerBound: Storage.generalize($0.lowerBound), 
                        upperBound: Storage.generalize($0.upperBound)) 
                }
            }
            func passRetained() -> Godot.Unmanaged.Variant 
            {
                Storage.RectangleAggregate.variant(packing: .init(
                    lowerBound: Storage.specialize(self.lowerBound), 
                    upperBound: Storage.specialize(self.upperBound)))
            }
        }
        extension Vector.Rectangle:Godot.Variant 
            where Storage:Godot.RectangleStorage, T == Float32 
        {
        }
        extension Vector.Rectangle:Godot.VariantRepresentable 
            where Storage:Godot.RectangleStorage, T:Comparable
        {
        } 
        extension Vector.ClosedRectangle:Godot.VariantRepresentable  
            where Storage:Godot.RectangleStorage, T:Comparable
        {
        } 
        """
    }
}
