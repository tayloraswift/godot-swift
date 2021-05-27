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
        ///     as long as [`(VectorFiniteRangeExpression).Bound.Storage`] conforms 
        ///     to this protocol.
        /// 
        ///     Conditional conformances to [`Godot.VariantRepresentable`] 
        ///     have already been provided for [`Vector.Rectangle`] and 
        ///     [`Vector.ClosedRectangle`]. You can add support for additional 
        ///     [`VectorFiniteRangeExpression`] types by explicitly declaring the 
        ///     conformance to [`Godot.VariantRepresentable`] in user code.
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
            "extension \(type):Godot.RectangleElement {}"
        }
        """
        extension VectorFiniteRangeExpression where Storage:Godot.RectangleStorage 
        {
            /// static var VectorFiniteRangeExpression.variantType:Godot.VariantType { get }
            /// ?   where Storage:Godot.RectangleStorage 
            ///     Allows types conforming to this protocol to also conform to 
            ///     [`Godot.VariantRepresentable`], if explicitly declared.
            static 
            var variantType:Godot.VariantType 
            {
                Storage.RectangleAggregate.variantType
            }
            /// static func VectorFiniteRangeExpression.takeUnretained(_:)
            /// ?   where Storage:Godot.RectangleStorage 
            ///     Allows types conforming to this protocol to also conform to 
            ///     [`Godot.VariantRepresentable`], if explicitly declared.
            /// - value :Godot.Unmanaged.Variant 
            /// - ->    :Self? 
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
            /// func VectorFiniteRangeExpression.passRetained()
            /// ?   where Storage:Godot.RectangleStorage 
            ///     Allows types conforming to this protocol to also conform to 
            ///     [`Godot.VariantRepresentable`], if explicitly declared.
            /// - ->    :Godot.Unmanaged.Variant 
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
