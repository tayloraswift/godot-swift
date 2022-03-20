enum Rectangle 
{
    @Source.Code 
    static 
    var swift:String 
    {
        """
        /// protocol VectorRangeExpression 
        ///     A type representing an *n*-dimensional axis-aligned region.
        /// #   (1:vector-range-types)
        /// #   (0:math-protocols)
        protocol VectorRangeExpression
        {
            /// associatedtype VectorRangeExpression.Storage 
            /// where Storage:SIMD 
            
            /// associatedtype VectorRangeExpression.T 
            /// where T:SIMDScalar, T == Storage.Scalar  
            
            associatedtype Storage  where Storage:SIMD 
            associatedtype T        where T:SIMDScalar, T == Storage.Scalar 
            
            /// typealias VectorRangeExpression.Bound = Vector<Storage, T>
            ///     The vector type representing the bounds of this vector 
            ///     range expression.
            typealias Bound = Vector<Storage, T>
            
            /// func VectorRangeExpression.contains(_:)
            /// required 
            ///     Returns a boolean value indicating whether the given element 
            ///     is contained within the vector range expression.
            /// - element   :Bound 
            ///     The element to check for containment.
            /// - ->        :Bool 
            ///     `true` if `element` is contained in this vector range; 
            ///     otherwise, `false`.
            func contains(_ element:Bound) -> Bool 
        }
        extension VectorRangeExpression 
        {
            /// static func VectorRangeExpression.(~=)(pattern:element:) 
            ///     Returns a boolean value indicating whether a value is 
            ///     included in a vector range.
            /// - pattern   :Self
            ///     A vector range.
            /// - element   :Bound 
            ///     A value to match against `pattern`.
            /// - ->        :Bool 
            ///     `true` if `element` is contained in the vector range `pattern`; 
            ///     otherwise, `false`.
            /// #   (0:vector-region-test-usage)
            static 
            func ~= (pattern:Self, element:Bound) -> Bool 
            {
                pattern.contains(element)
            }
        }
        
        /// protocol VectorFiniteRangeExpression
        /// :   VectorRangeExpression 
        ///     A type representing an *n*-dimensional axis-aligned rectangle.
        /// #   [Creating a finite range expression](vectorfiniterangeexpression-required-init)
        /// #   [Converting finite range expressions between scalar types](vectorfiniterangeexpression-type-conversion-usage)
        /// #   [Getting the bounds of a finite range expression](vectorfiniterangeexpression-required-property)
        /// #   (2:vector-range-types)
        /// #   (0:math-protocols)
        protocol VectorFiniteRangeExpression:VectorRangeExpression 
        {
            /// init VectorFiniteRangeExpression.init(lowerBound:upperBound:)
            /// required 
            ///     Creates a finite vector range with the given bounds.
            /// - lowerBound    :Bound 
            ///     The lower bound.
            /// - upperBound    :Bound 
            ///     The upper bound.
            /// #   (vectorfiniterangeexpression-required-init)
            init(lowerBound:Bound, upperBound:Bound)
            
            /// var VectorFiniteRangeExpression.lowerBound:Bound 
            /// required 
            ///     The lower bound of this vector range.
            /// #   (vectorfiniterangeexpression-required-property)
            var lowerBound:Bound 
            {
                get 
            }
            /// var VectorFiniteRangeExpression.upperBound:Bound 
            /// required 
            ///     The upper bound of this vector range.
            /// #   (vectorfiniterangeexpression-required-property)
            var upperBound:Bound 
            {
                get 
            }
        }
        """
        for domain:String in ["FixedWidthInteger", "BinaryFloatingPoint"] 
        {
            """
            extension VectorFiniteRangeExpression where T:\(domain) 
            """
            Source.block 
            {
                """
                /// static var VectorFiniteRangeExpression.zero:Self { get }
                /// ?   where T:\(domain)
                ///     A finite vector range with zero in both its bounds.
                static 
                var zero:Self 
                {
                    .init(lowerBound: .zero, upperBound: .zero)
                }
                /// var VectorFiniteRangeExpression.size:Vector<Storage, T> { get }
                /// ?   where T:\(domain)
                ///     The dimensions of this finite vector range, obtained 
                ///     by subtracting [`lowerBound`] from [`upperBound`].
                var size:Vector<Storage, T> 
                {
                    self.upperBound - self.lowerBound
                }
                """
                if domain == "BinaryFloatingPoint"
                {
                    """
                    /// var VectorFiniteRangeExpression.midpoint:Vector<Storage, T> { get }
                    /// ?   where T:\(domain)
                    ///     The midpoint of this finite vector range, obtained 
                    ///     by interpolating halfway between [`lowerBound`] and [`upperBound`].
                    var midpoint:Vector<Storage, T> 
                    {
                        (self.lowerBound .. self.upperBound)(0.5)
                    }
                    """
                }
            }
        }
        for n:Int in 2 ... 4 
        {
            """
            extension VectorFiniteRangeExpression where Storage == SIMD\(n)<T>, T:FixedWidthInteger
            """
            Source.block
            {
                """
                /// init VectorFiniteRangeExpression.init<Other, U>(clamping:) 
                /// where Other:VectorFiniteRangeExpression, Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts a finite integer vector range with bounds with 
                ///     elements of type [[`U`]] to a finite integer vector range with 
                ///     bounds with elements of type [[`T`]], with each element of 
                ///     each bound clamped to the range of values representable 
                ///     by [[`T`]].
                /// - other :Other
                /// #   (\(n):vectorfiniterangeexpression-type-conversion-usage)
                init<Other:VectorFiniteRangeExpression, U>(clamping other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                {
                    self.init(
                        lowerBound: .init(clamping: other.lowerBound),
                        upperBound: .init(clamping: other.upperBound))
                }
                /// init VectorFiniteRangeExpression.init<Other, U>(truncatingIfNeeded:) 
                /// where Other:VectorFiniteRangeExpression, Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts a finite integer vector range with bounds with 
                ///     elements of type [[`U`]] to a finite integer vector range with 
                ///     bounds with elements of type [[`T`]], with each element of 
                ///     each bound truncated to the bit width of [[`T`]].
                /// - other :Other
                /// #   (\(n):vectorfiniterangeexpression-type-conversion-usage)
                init<Other:VectorFiniteRangeExpression, U>(truncatingIfNeeded other:Other)
                    where Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                {
                    self.init(
                        lowerBound: .init(truncatingIfNeeded: other.lowerBound),
                        upperBound: .init(truncatingIfNeeded: other.upperBound))
                }
                
                /// init VectorFiniteRangeExpression.init<Other, U>(_:) 
                /// where Other:VectorFiniteRangeExpression, Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts a finite floating point vector range with bounds with 
                ///     elements of type [[`U`]] to a finite integer vector range with 
                ///     bounds with elements of type [[`T`]].
                /// - other :Other
                /// #   (\(n):vectorfiniterangeexpression-type-conversion-usage)
                init<Other:VectorFiniteRangeExpression, U>(_ other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                {
                    self.init(
                        lowerBound: .init(other.lowerBound),
                        upperBound: .init(other.upperBound))
                }
                /// init VectorFiniteRangeExpression.init<Other, U>(_:rounding:) 
                /// where Other:VectorFiniteRangeExpression, Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts a finite floating point vector range with bounds with 
                ///     elements of type [[`U`]] to a finite integer vector range with 
                ///     bounds with elements of type [[`T`]], with each element of 
                ///     each bound rounded according to the given floating point 
                ///     rounding rule.
                /// - other :Other
                /// - rule  :FloatingPointRoundingRule
                /// #   (\(n):vectorfiniterangeexpression-type-conversion-usage)
                init<Other:VectorFiniteRangeExpression, U>(_ other:Other, 
                    rounding rule:FloatingPointRoundingRule) 
                    where Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                {
                    self.init(
                        lowerBound: .init(other.lowerBound, rounding: rule),
                        upperBound: .init(other.upperBound, rounding: rule))
                } 
                """
            }
            """
            extension VectorFiniteRangeExpression where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
            """
            Source.block
            {
                """
                /// init VectorFiniteRangeExpression.init<Other, U>(_:) 
                /// where Other:VectorFiniteRangeExpression, Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                /// ?   where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
                ///     Converts a finite integer vector range with bounds with 
                ///     elements of type [[`U`]] to a finite floating point vector range with 
                ///     bounds with elements of type [[`T`]].
                /// - other :Other
                /// #   (\(n):vectorfiniterangeexpression-type-conversion-usage)
                init<Other:VectorFiniteRangeExpression, U>(_ other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                {
                    self.init(
                        lowerBound: .init(other.lowerBound),
                        upperBound: .init(other.upperBound))
                }
                /// init VectorFiniteRangeExpression.init<Other, U>(_:) 
                /// where Other:VectorFiniteRangeExpression, Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                /// ?   where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
                ///     Converts a finite floating point vector range with bounds with 
                ///     elements of type [[`U`]] to a finite floating point vector range with 
                ///     bounds with elements of type [[`T`]].
                /// - other :Other
                /// #   (\(n):vectorfiniterangeexpression-type-conversion-usage)
                init<Other:VectorFiniteRangeExpression, U>(_ other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                {
                    self.init(
                        lowerBound: .init(other.lowerBound),
                        upperBound: .init(other.upperBound))
                }
                """
            }
        }
        """
        
        extension Vector where T:Comparable
        """
        Source.block 
        {
            """
            /// struct Vector.Rectangle 
            /// :   VectorFiniteRangeExpression 
            /// :   Hashable 
            /// :   Godot.VariantRepresentable  where Storage:Godot.RectangleStorage
            /// :   Godot.Variant               where Storage:Godot.RectangleStorage, T == Float32 
            /// ?   where T:Comparable 
            ///     An *n*-dimensional half-open axis-aligned region from a lower 
            ///     bound up to, but not including, an upper bound.
            /// 
            ///     Create a rectangle using the [`(Vector).(..<)(lower:upper:)`] 
            ///     operator. 
            /// #   (0:vector-range-types)
            /// #   (5:math-types)
            /// #   (22:godot-core-types)
            /// #   (22:)
            struct Rectangle:VectorFiniteRangeExpression, Hashable
            {
                /// var Vector.Rectangle.lowerBound:Vector<Storage, T>
                /// ?:  VectorFiniteRangeExpression
                ///     The lower bound of this axis-aligned rectangle.
                var lowerBound:Vector<Storage, T>
                /// var Vector.Rectangle.upperBound:Vector<Storage, T>
                /// ?:  VectorFiniteRangeExpression
                ///     The upper bound of this axis-aligned rectangle.
                var upperBound:Vector<Storage, T>
                
                /// func Vector.Rectangle.contains(_:)
                /// ?:  VectorRangeExpression
                ///     Indicates whether the given element is contained within 
                ///     this half-open axis-aligned rectangle.
                /// - element   :Vector<Storage, T> 
                ///     The element to check for containment.
                /// - ->        :Bool 
                ///     `true` if `element` is contained in this half-open 
                ///     axis-aligned rectangle; otherwise, `false`.
                func contains(_ element:Vector<Storage, T>) -> Bool 
                {
                    Vector<Storage, T>.all(
                        (self.lowerBound <= element) & (element < self.upperBound))
                }
            }
            
            /// struct Vector.ClosedRectangle 
            /// :   VectorFiniteRangeExpression 
            /// :   Hashable
            /// :   Godot.VariantRepresentable where Storage:Godot.RectangleStorage
            /// ?   where T:Comparable 
            ///     An *n*-dimensional axis-aligned region from a lower 
            ///     bound up to, and including, an upper bound.
            /// 
            ///     Create a closed rectangle using the [`(Vector).(...)(lower:upper:)`] 
            ///     operator. 
            /// #   (0:vector-range-types)
            /// #   (5:math-types)
            /// #   (23:)
            struct ClosedRectangle:VectorFiniteRangeExpression, Hashable
            {
                /// var Vector.ClosedRectangle.lowerBound:Vector<Storage, T>
                /// ?:  VectorFiniteRangeExpression
                ///     The lower bound of this axis-aligned rectangle.
                var lowerBound:Vector<Storage, T>
                /// var Vector.ClosedRectangle.upperBound:Vector<Storage, T>
                /// ?:  VectorFiniteRangeExpression
                ///     The upper bound of this axis-aligned rectangle.
                var upperBound:Vector<Storage, T>
                
                /// func Vector.ClosedRectangle.contains(_:)
                /// ?:  VectorRangeExpression
                ///     Indicates whether the given element is contained within 
                ///     this axis-aligned rectangle.
                /// - element   :Vector<Storage, T> 
                ///     The element to check for containment.
                /// - ->        :Bool 
                ///     `true` if `element` is contained in this 
                ///     axis-aligned rectangle; otherwise, `false`.
                func contains(_ element:Vector<Storage, T>) -> Bool 
                {
                    Vector<Storage, T>.all(
                        (self.lowerBound <= element) & (element <= self.upperBound))
                }
            }
            
            /// static func Vector.(..<)(lower:upper:)
            /// ?   where T:Comparable 
            ///     Returns a half-open axis-aligned rectangle with the given bounds.
            /// - lower :Self 
            ///     The lower bound.
            /// - upper :Self 
            ///     The upper bound.
            /// - ->    :Rectangle 
            ///     A half-open axis-aligned rectangle.
            /// #   (0:vector-range-creation)
            static 
            func ..< (lower:Self, upper:Self) -> Rectangle
            {
                .init(lowerBound: lower, upperBound: upper)
            }
            /// static func Vector.(...)(lower:upper:)
            /// ?   where T:Comparable 
            ///     Returns an axis-aligned rectangle with the given bounds.
            /// - lower :Self 
            ///     The lower bound.
            /// - upper :Self 
            ///     The upper bound.
            /// - ->    :ClosedRectangle 
            ///     An axis-aligned rectangle.
            /// #   (1:vector-range-creation)
            static 
            func ... (lower:Self, upper:Self) -> ClosedRectangle
            {
                .init(lowerBound: lower, upperBound: upper)
            }
            
            /// func Vector.clamped(to:)
            /// ?   where T:Comparable 
            ///     Creates a new vector with each element clamped to the extents 
            ///     of the given axis-aligned rectangle.
            /// - rectangle :ClosedRectangle 
            ///     An axis-aligned rectangle.
            /// - ->        :Self 
            ///     A new vector, where each element is contained within the 
            ///     corresponding lanewise bounds of `rectangle`.
            /// #   (0:vector-range-usage)
            func clamped(to rectangle:ClosedRectangle) -> Self 
            {
                .init(storage: self.storage.clamped(
                    lowerBound: rectangle.lowerBound.storage,
                    upperBound: rectangle.upperBound.storage))
            }
            /// mutating func Vector.clamp(to:)
            /// ?   where T:Comparable 
            ///     Clamps each element of this vector to the extents 
            ///     of the given axis-aligned rectangle.
            /// - rectangle :ClosedRectangle 
            ///     An axis-aligned rectangle.
            /// #   (0:vector-range-usage)
            mutating 
            func clamp(to rectangle:ClosedRectangle) 
            {
                self.storage.clamp(
                    lowerBound: rectangle.lowerBound.storage,
                    upperBound: rectangle.upperBound.storage)
            } 
            """
        }
    }
}
