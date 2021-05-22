enum Vector 
{
    private static 
    func permutations(_ n:Int) -> [[Int]] 
    {
        func permutations(_ n:Int, k:Int) -> [[Int]] 
        {
            if k <= 0 
            {
                return [[]]
            }
            else 
            {
                return permutations(n, k: k - 1).flatMap
                {
                    (body:[Int]) -> [[Int]] in 
                    (0 ..< n).map 
                    {
                        (head:Int) -> [Int] in 
                        [head] + body
                    }
                }
            }
        }
        
        return permutations(n, k: n)
    }
    
    private static 
    func initializers(n:Int, components:ArraySlice<String>) -> String 
    {
        let patterns:[[Int]] 
        switch n 
        {
        case 2:
            patterns = []
        case 3:
            patterns = 
            [
                [2, 1], 
                [1, 2],
            ]
        case 4:
            patterns = 
            [
                [2, 1, 1], 
                [1, 2, 1],
                [1, 1, 2],
                [2, 2],
                [3, 1],
                [1, 3],
            ]
        default:
            fatalError("unreachable")
        }
        
        return Source.fragment
        {
            """
            init(\(components.map{ "_ \($0):T" }.joined(separator: ", "))) 
            {
                self.init(storage: .init(\(components.joined(separator: ", "))))
            }
            """
            for pattern:[Int] in patterns 
            {
                var containers:[String] = []
                var accessors:[String]  = []
                var index:Int           = components.startIndex 
                for count:Int in pattern 
                {
                    if count == 1 
                    {
                        let variable:String = components[index]
                        let _:Void = containers.append("_ \(variable):T")
                        let _:Void = accessors.append(variable)
                    }
                    else 
                    {
                        let variable:String = components[index ..< index + count].joined()
                        let _:Void = containers.append("_ \(variable):Vector\(count)<T>")
                        
                        for component:String in components.prefix(count)
                        {
                            let _:Void = accessors.append("\(variable).\(component)")
                        }
                    }
                    
                    let _:Void = index += count 
                }
                
                """
                init(\(containers.joined(separator: ", "))) 
                {
                    self.init(\(accessors.joined(separator: ", ")))
                }
                """
            }
        }
    }
    
    private static 
    func define(comparator:String, prose:String, condition:String) -> String 
    {
        """
        /// static func Vector.(\(comparator))(lhs:rhs:)
        /// ?   where T:\(condition) 
        ///     Returns a vector mask with the result of a elementwise 
        ///     \(prose) comparison of two vectors.
        /// - lhs   :Self 
        /// - rhs   :Self 
        /// - ->    :Mask 
        ///     A vector mask where each element is set if the corresponding 
        ///     element of `lhs` is \(prose) the corresponding element 
        ///     of `rhs`.
        /// #   (1:vector-comparison-usage)
        static 
        func \(comparator) (lhs:Self, rhs:Self) -> Mask 
        {
            .init(storage: lhs.storage .\(comparator) rhs.storage)
        }
        /// static func Vector.(\(comparator))(lhs:scalar:)
        /// ?   where T:\(condition) 
        ///     Returns a vector mask with the result of a elementwise 
        ///     \(prose) comparison of a vector with a scalar value.
        /// - lhs   :Self 
        /// - scalar:T 
        /// - ->    :Mask 
        ///     A vector mask where each element is set if the corresponding 
        ///     element of `lhs` is \(prose) `scalar`.
        /// #   (1:vector-comparison-usage)
        static 
        func \(comparator) (lhs:Self, scalar:T) -> Mask 
        {
            .init(storage: lhs.storage .\(comparator) scalar)
        }
        /// static func Vector.(\(comparator))(scalar:rhs:)
        /// ?   where T:\(condition) 
        ///     Returns a vector mask with the result of a elementwise 
        ///     \(prose) comparison of a scalar value with a vector.
        /// - scalar:T
        /// - rhs   :Self 
        /// - ->    :Mask 
        ///     A vector mask where each element is set if `scalar` is \(prose) 
        ///     the corresponding element of `rhs`.
        /// #   (1:vector-comparison-usage)
        static 
        func \(comparator) (scalar:T, rhs:Self) -> Mask 
        {
            .init(storage: scalar .\(comparator) rhs.storage)
        }
        """
    }
    
    @Source.Code 
    private static 
    var code:String 
    {
        let components:
        (
            cartesian:[String], 
            _:Void 
        ) 
        = 
        (
            cartesian: ["x", "y", "z", "w"], 
            ()
        )
        
        let numeric:[String] = ["FixedWidthInteger", "BinaryFloatingPoint"]
        
        """
        import protocol Numerics.Real
        
        /// operator .. : RangeFormationPrecedence 
        ///     Represents an interpolation range expression.
        
        /// operator <> : MultiplicationPrecedence 
        ///     Represents a dot- or inner-product operation.
        
        /// operator >|< : MultiplicationPrecedence 
        ///     Represents a cross-product operation.
        
        /// operator >< : MultiplicationPrecedence 
        ///     Represents a vector- or matrix-product operation.
        
        /// postfix operator * 
        ///     Represents a transpose operation. This operator can be used to 
        ///     express vectors and matrices as tuple literals.
        
        /// infix operator ~<  : ComparisonPrecedence 
        ///     Represents a region membership test.
        
        /// infix operator ~~  : ComparisonPrecedence 
        ///     Represents a region membership test.
        
        /// infix operator !~  : ComparisonPrecedence 
        ///     Represents a region membership test.
        
        /// infix operator !>  : ComparisonPrecedence 
        ///     Represents a region membership test.
        
        infix   operator ..  : RangeFormationPrecedence 
        
        infix   operator <>  : MultiplicationPrecedence 
        infix   operator >|< : MultiplicationPrecedence 
        infix   operator ><  : MultiplicationPrecedence 
        
        postfix operator *
        
        infix   operator ~<  : ComparisonPrecedence     // vector is inside sphere, exclusive
        infix   operator ~~  : ComparisonPrecedence     // vector is inside sphere, inclusive
        infix   operator !~  : ComparisonPrecedence     // vector is outside sphere, inclusive
        infix   operator !>  : ComparisonPrecedence     // vector is outside sphere, exclusive
        
        // we must parameterize the `Storage<T>` and `T` types separately, or 
        // else we cannot specialize on `Storage<_>` while keeping `T` generic.
        
        /// struct Vector<Storage, T> 
        /// :   Hashable 
        /// :   CustomStringConvertible where Storage:SIMD.Transposable
        /// where Storage:SIMD, T:SIMDScalar, T == Storage.Scalar 
        ///     An SIMD-backed vector.
        /// #   [Fixed-length vectors](vector-fixed-length-specializations)
        /// #   [Matrix types](vector-matrix-types)
        /// #   [Creating vectors](vector-initializer-usage)
        /// #   [Transforming vectors](vector-map)
        /// #   [Vector constants](vector-constants)
        /// #   [Matrix constants](matrix-constants)
        /// #   [Vector range types](vector-range-types)
        /// #   [Creating vector ranges](vector-range-creation)
        /// #   [Using vector ranges](vector-range-usage)
        /// #   [Interpolating vectors](vector-interpolation-usage)
        /// #   [Horizontal operations](vector-horizontal-operations)
        /// #   [Normalizing vectors](vector-normalization-usage)
        /// #   [Rounding vectors](vector-rounding-usage)
        /// #   [Elementwise arithmetic](vector-elementwise-arithmetic)
        /// #   [Elementwise binary operations](vector-elementwise-binary-operations)
        /// #   [Bitwise operations](vector-bitwise-operations)
        /// #   [Elementary functions](vector-elementwise-elementary-functions)
        /// #   [Computing cross products](vector-cross-products)
        /// #   [Linear operations](vector-linear-operations)
        /// #   [Working with binary representation](vector-binary-representation-usage)
        /// #   [Using vector masks](vector-mask-usage)
        /// #   [Comparing vectors](vector-comparison-usage)
        /// #   [Testing for region membership](vector-region-test-usage)
        struct Vector<Storage, T>:Hashable 
            where Storage:SIMD, T:SIMDScalar, T == Storage.Scalar
        {
            /// struct Vector.Mask 
            ///     An SIMD-backed vector mask.
            /// #   (0:vector-mask-usage)
            struct Mask
            {
                /// var Vector.Mask.storage:SIMDMask<Storage.MaskStorage> 
                ///     The SIMD backing storage of this vector mask.
                var storage:SIMDMask<Storage.MaskStorage>
            }
            
            /// var Vector.storage:Storage 
            ///     The SIMD backing storage of this vector.
            var storage:Storage 
            
            /// init Vector.init(storage:)
            ///     Creates a vector instance with the given SIMD value.
            /// - storage   :Storage 
            ///     An SIMD value.
            /// #   (vector-initializer-usage)
            init(storage:Storage)
            {
                self.storage = storage
            }
        }
        extension Vector 
        {
            /// static func Vector.any(_:)
            ///     Returns a boolean value indicating if any element of the given 
            ///     vector mask is set. 
            /// - mask  :Mask 
            ///     A vector mask.
            /// - ->    :Bool 
            ///     `true` if any element of `mask` is set; otherwise, `false`.
            /// #   (1:vector-mask-usage)
            static 
            func any(_ mask:Mask) -> Bool 
            {
                Swift.any(mask.storage)
            }
            /// static func Vector.all(_:)
            ///     Returns a boolean value indicating if all elements of the given 
            ///     vector mask are set. 
            /// - mask  :Mask 
            ///     A vector mask.
            /// - ->    :Bool 
            ///     `true` if all elements of `mask` are set; otherwise, `false`.
            /// #   (1:vector-mask-usage)
            static 
            func all(_ mask:Mask) -> Bool 
            {
                Swift.all(mask.storage)
            }
        }
        
        // initializations 
        extension Vector 
        {
            /// init Vector.init(repeating:)
            ///     Creates a vector instance with the given scalar value 
            ///     repeated in all elements.
            /// - value     :T 
            ///     A scalar value.
            /// #   (vector-initializer-usage)
            init(repeating value:T) 
            {
                self.init(storage: .init(repeating: value))
            }
        }
        extension Vector where T:AdditiveArithmetic 
        {
            /// init Vector.init(to:where:else:)
            /// ?   where T:AdditiveArithmetic
            ///     Creates a vector instance with one of the two given scalar values 
            ///     repeated in all elements, depending on the given mask.
            /// - value     :T 
            ///     The scalar value to use where `mask` is set.
            /// - mask      :Mask  
            ///     The vector mask used to choose between `value` and `empty`.
            /// - empty     :T 
            ///     The scalar value to use where `mask` is clear.
            ///     
            ///     The default value is [`AdditiveArithmetic`zero`].
            /// #   (vector-initializer-usage)
            init(to value:T, where mask:Mask, else empty:T = .zero) 
            {
                self.init(storage: .init(repeating: empty).replacing(with: value, where: mask.storage))
            }
        }
        // assignments
        extension Vector 
        {
            /// mutating func Vector.replace(with:where:)
            ///     Conditionally replaces the elements of this vector with the 
            ///     given scalar value, according to the given mask.
            /// - scalar    :T 
            ///     The new scalar value. 
            /// - mask      :Mask 
            ///     The vector mask used to conditionally assign `scalar`.
            /// #   (2:vector-mask-usage)
            mutating 
            func replace(with scalar:T, where mask:Mask) 
            {
                self.storage.replace(with: scalar, where: mask.storage)
            }
            /// mutating func Vector.replace(with:where:)
            ///     Conditionally replaces the elements of this vector with the 
            ///     elements of the given vector, according to the given mask.
            /// - other     :Self 
            ///     A vector containing the new elements. 
            /// - mask      : Mask 
            ///     The vector mask used to conditionally assign elements of `other`.
            /// #   (2:vector-mask-usage)
            mutating 
            func replace(with other:Self, where mask:Mask) 
            {
                self.storage.replace(with: other.storage, where: mask.storage)
            }
            
            /// func Vector.replacing(with:where:)
            ///     Creates a new vector, replacing the elements of this vector with the 
            ///     given scalar value, according to the given mask.
            /// - scalar    :T 
            ///     The new scalar value. 
            /// - mask      :Mask 
            ///     The vector mask used to choose between the elements of this 
            ///     vector, and `scalar`.
            /// - ->        :Self 
            ///     The new vector.
            /// #   (2:vector-mask-usage)
            func replacing(with scalar:T, where mask:Mask) -> Self
            {
                .init(storage: self.storage.replacing(with: scalar, where: mask.storage))
            }
            /// func Vector.replacing(with:where:)
            ///     Creates a new vector, replacing the elements of this vector with the 
            ///     elements of the given vector, according to the given mask.
            /// - other     :Self 
            ///     A vector containing the new elements. 
            /// - mask      :Mask 
            ///     The vector mask used to choose between the elements of this 
            ///     vector, and the elements of `other`.
            /// - ->        :Self 
            ///     The new vector.
            /// #   (2:vector-mask-usage)
            func replacing(with other:Self, where mask:Mask) -> Self
            {
                .init(storage: self.storage.replacing(with: other.storage, where: mask.storage))
            }
        }
        
        // `Comparable`-related functionality
        /// protocol VectorRangeExpression 
        ///     A type representing an *n*-dimensional axis-aligned region.
        /// #   (1:vector-range-types)
        protocol VectorRangeExpression
        {
            /// associatedtype VectorRangeExpression.Storage 
            /// where Storage:SIMD 
            /// required 
            
            /// associatedtype VectorRangeExpression.T 
            /// where T:SIMDScalar, T == Storage.Scalar  
            /// required 
            
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
        /// #   (2:vector-range-types)
        protocol VectorFiniteRangeExpression:VectorRangeExpression 
        {
            /// init VectorFiniteRangeExpression.init(lowerBound:upperBound:)
            /// required 
            ///     Creates a finite vector range with the given bounds.
            /// - lowerBound    :Bound 
            ///     The lower bound.
            /// - upperBound    :Bound 
            ///     The upper bound.
            init(lowerBound:Bound, upperBound:Bound)
            
            /// var VectorFiniteRangeExpression.lowerBound:Bound 
            /// required 
            ///     The lower bound of this vector range.
            var lowerBound:Bound 
            {
                get 
            }
            /// var VectorFiniteRangeExpression.upperBound:Bound 
            /// required 
            ///     The upper bound of this vector range.
            var upperBound:Bound 
            {
                get 
            }
        }
        
        extension Vector where T:Comparable
        """
        Source.block 
        {
            """
            /// struct Vector.Rectangle 
            /// :   VectorFiniteRangeExpression 
            /// :   Hashable
            /// ?   where T:Comparable 
            ///     An *n*-dimensional half-open axis-aligned region from a lower 
            ///     bound up to, but not including, an upper bound.
            /// #   (0:vector-range-types)
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
            /// ?   where T:Comparable 
            ///     An *n*-dimensional axis-aligned region from a lower 
            ///     bound up to, and including, an upper bound.
            /// #   (0:vector-range-types)
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
            
            /// static func Vector.(..<)(lhs:rhs:)
            /// ?   where T:Comparable 
            ///     Returns a half-open axis-aligned rectangle with the given bounds.
            /// - lhs   :Self 
            ///     The lower bound.
            /// - rhs   :Self 
            ///     The upper bound.
            /// - ->    :Rectangle 
            ///     A half-open axis-aligned rectangle.
            /// #   (0:vector-range-creation)
            static 
            func ..< (lhs:Self, rhs:Self) -> Rectangle
            {
                .init(lowerBound: lhs, upperBound: rhs)
            }
            /// static func Vector.(...)(lhs:rhs:)
            /// ?   where T:Comparable 
            ///     Returns an axis-aligned rectangle with the given bounds.
            /// - lhs   :Self 
            ///     The lower bound.
            /// - rhs   :Self 
            ///     The upper bound.
            /// - ->    :ClosedRectangle 
            ///     An axis-aligned rectangle.
            /// #   (1:vector-range-creation)
            static 
            func ... (lhs:Self, rhs:Self) -> ClosedRectangle
            {
                .init(lowerBound: lhs, upperBound: rhs)
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
            for (comparator, prose):(String, String) in 
            [
                ("<",   "less than"), 
                ("<=",  "less than or equal to"), 
                (">=",  "greater than or equal to"), 
                (">",   "greater than"),
            ] 
            {
                Self.define(comparator: comparator, prose: prose, condition: "Swift.Comparable")
            }
            for (vended, base, prose):(String, String, String) in 
            [
                ("min", "pointwiseMin", "minimum"), 
                ("max", "pointwiseMax", "maximum")
            ] 
            {
                """
                /// static func Vector.\(vended)(_:_:)
                /// ?   where T:Comparable 
                ///     Returns the result of an elementwise \(vended) operation.
                /// - a :Self 
                /// - b :Self 
                /// - ->:Self 
                ///     A vector where each element is the \(prose) of the corresponding 
                ///     elements of `a` and `b`.
                /// #   (0:vector-elementwise-elementary-functions)
                static 
                func \(vended)(_ a:Self, _ b:Self) -> Self
                {
                    .init(storage: \(base)(a.storage, b.storage))
                }
                """
            }
            for (vended, base, prose):(String, String, String) in 
            [
                ("min", "min", "minimum"), 
                ("max", "max", "maximum")
            ] 
            {
                """
                /// var Vector.\(vended):T { get }
                /// ?   where T:Comparable 
                ///     The value of the \(prose) element of this vector.
                /// #   (0:vector-horizontal-operations)
                var \(vended):T 
                {
                    self.storage.\(base)()
                }
                """
            }
        }
        """
        
        extension Vector where T:Equatable 
        """
        Source.block 
        {
            for (comparator, prose):(String, String) in 
            [
                ("!=",  "not equal to"), 
                ("==",  "equal to"), 
            ] 
            {
                Self.define(comparator: comparator, prose: prose, condition: "Swift.Equatable")
            }
        }
        """
        
        extension Vector where T:SignedInteger & FixedWidthInteger 
        {
            /// static func Vector.abs(clamping:)
            /// ?   where T:SignedInteger & FixedWidthInteger
            ///     Performs an elementwise absolute value operation on the 
            ///     given vector, clamping the result to the range of values 
            ///     representable by [[`T`]].
            /// 
            ///     **Note:** Elements with the value `T.min` are mapped to 
            ///     the value `T.max`. All other values are transformed according 
            ///     to the mathematical definition of absolute value.
            /// 
            ///     **Note:** To obtain the scalar magnitude of an integer vector, 
            ///     convert it to floating point vector, and use the 
            ///     [`norm`] instance property.
            /// - value :Self
            ///     A vector. 
            /// - ->    :Self 
            ///     A vector where each element contains the absolute value of 
            ///     the corresponding element of `value`, or `T.max` if the 
            ///     original element was `T.min`.
            /// #   (0:vector-elementwise-elementary-functions)
            static 
            func abs(clamping value:Self) -> Self 
            {
                // saturating twos complement negation
                .max(~value, .abs(wrapping: value))
            }
            /// static func Vector.abs(wrapping:)
            /// ?   where T:SignedInteger & FixedWidthInteger
            ///     Performs an elementwise absolute value operation on the 
            ///     given vector, with two’s-complement wraparound if the resulting 
            ///     elements are not representable by [[`T`]].
            /// 
            ///     **Note:** Elements with the value `T.min` will remain `T.min`, 
            ///     as the value `-T.min` is equivalent to `T.max` when truncated 
            ///     to the bit width of [[`T`]]. All other values are transformed according 
            ///     to the mathematical definition of absolute value.
            /// 
            ///     **Note:** To obtain the scalar magnitude of an integer vector, 
            ///     convert it to floating point vector, and use the 
            ///     [`norm`] instance property.
            /// - value :Self
            ///     A vector. 
            /// - ->    :Self 
            ///     A vector where each element contains the absolute value of 
            ///     the corresponding element of `value`, or `T.min` if the 
            ///     original element was `T.min`.
            /// #   (0:vector-elementwise-elementary-functions)
            static 
            func abs(wrapping value:Self) -> Self 
            {
                .max(value, 0 - value)
            }
        }
        extension Vector where T:BinaryFloatingPoint 
        {
            /// static func Vector.abs(_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Performs an elementwise absolute value operation on the 
            ///     given vector.
            ///
            ///     **Note:** To obtain the scalar magnitude of a vector, use the 
            ///     [`norm`] instance property.
            /// - value :Self
            ///     A vector. 
            /// - ->    :Self 
            ///     A vector where each element contains the absolute value of 
            ///     the corresponding element of `value`, or `T.nan` if the original 
            ///     element was `T.nan`.
            /// #   (0:vector-elementwise-elementary-functions)
            static 
            func abs(_ value:Self) -> Self 
            {
                .max(value, -value)
            }
        }
        extension Vector.Mask 
        """
        Source.block 
        {
            let operators:[(vended:String, base:String, prose:String)] = 
            [
                ("|", ".|", "or"),
                ("&", ".&", "and"),
                ("^", ".^", "xor"),
            ]
            for (vended, base, prose):(String, String, String) in operators
            {
                """
                /// static func Vector.Mask.(\(vended))(lhs:rhs:)
                ///     Returns the result of a bitwise *\(prose)* operation on 
                ///     the given vector masks.
                /// - lhs   :Self 
                /// - rhs   :Self 
                /// - ->    :Self 
                ///     The bitwise result of `lhs` *\(prose)* `rhs`.
                static 
                func \(vended) (lhs:Self, rhs:Self) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs.storage)
                }
                /// static func Vector.Mask.(\(vended))(lhs:scalar:)
                ///     Returns the result of a bitwise *\(prose)* operation on 
                ///     the given vector mask, and the vector mask obtained by 
                ///     broadcasting the given boolean value.
                /// - lhs   :Self 
                /// - scalar:Bool  
                /// - ->    :Self 
                ///     A vector mask where each element contains the bitwise 
                ///     result of the corresponding element of `lhs` *\(prose)* `scalar`.
                static 
                func \(vended) (lhs:Self, scalar:Bool) -> Self 
                {
                    .init(storage: lhs.storage \(base) scalar)
                }
                /// static func Vector.Mask.(\(vended))(scalar:rhs:)
                ///     Returns the result of a bitwise *\(prose)* operation on 
                ///     the vector mask obtained by broadcasting the given boolean 
                ///     value, and the given vector mask.
                /// - scalar:Bool  
                /// - rhs   :Self 
                /// - ->    :Self 
                ///     A vector mask where each element contains the bitwise 
                ///     result of `scalar` *\(prose)* the corresponding element of `rhs`.
                static 
                func \(vended) (scalar:Bool, rhs:Self) -> Self 
                {
                    .init(storage: scalar \(base) rhs.storage)
                }
                """
            }
            // miscellaneous 
            """
            /// static prefix func Vector.Mask.(~)(rhs:)
            ///     Returns the result of a bitwise *not* operation on the given 
            ///     vector mask.
            /// - rhs   :Self 
            /// - ->    :Self 
            ///     The bitwise result of *not* `rhs`.
            static prefix 
            func ~ (rhs:Self) -> Self
            {
                .init(storage: .!rhs.storage)
            }
            """
            for (vended, base, prose):(String, String, String) in operators
            {
                """
                /// static func Vector.Mask.(\(vended)=)(lhs:rhs:)
                ///     Performs a bitwise *\(prose)* operation on 
                ///     the given vector masks, storing the result into `&lhs`.
                /// - lhs   :inout Self 
                /// - rhs   :Self 
                static 
                func \(vended)= (lhs:inout Self, rhs:Self)  
                {
                    lhs.storage \(base)= rhs.storage
                }
                /// static func Vector.Mask.(\(vended)=)(lhs:scalar:)
                ///     Performs a bitwise *\(prose)* operation on 
                ///     the given vector mask, and the vector mask obtained by 
                ///     broadcasting the given boolean value, storing the result 
                ///     into `&lhs`.
                /// - lhs   :inout Self 
                /// - scalar:Bool  
                static 
                func \(vended)= (lhs:inout Self, scalar:Bool)  
                {
                    lhs.storage \(base)= scalar
                }
                """
            }
        }
        """
        
        // constants 
        """
        for domain:String in numeric
        {
            """
            extension Vector where T:\(domain)
            {
                /// static var Vector.zero:Self { get }
                /// ?   where T:\(domain)
                ///     A vector with all elements set to zero.
                /// #   (0:vector-constants)
                static 
                var zero:Self   { .init(storage: .zero) }
                /// static var Vector.one:Self { get }
                /// ?   where T:\(domain)
                ///     A vector with all elements set to one.
                /// #   (1:vector-constants)
                static 
                var one:Self    { .init(storage:  .one) }
            }
            extension Vector.Diagonal where T:\(domain)
            {
                /// static var Vector.Diagonal.zero:Self { get }
                /// ?   where T:\(domain)
                ///     The zero matrix.
                /// #   (0:matrix-constants)
                static 
                var zero:Self       { Vector<Storage, T>.diagonal(.zero) }
                /// static var Vector.Diagonal.identity:Self { get }
                /// ?   where T:\(domain)
                ///     The identity matrix.
                /// #   (1:matrix-constants)
                static 
                var identity:Self   { Vector<Storage, T>.diagonal(.one)  }
            }
            """
        }
        """
        
        // horizontal operations 
        extension Vector where T:FixedWidthInteger
        {
            /// var Vector.sum:T { get }
            /// ?   where T:FixedWidthInteger 
            ///     The sum of all elements of this vector, with two’s-complement 
            ///     wraparound if the result is not representable by [[`T`]].
            /// #   (1:vector-horizontal-operations)
            var sum:T 
            {
                self.storage.wrappedSum()
            }
        }
        extension Vector where T:BinaryFloatingPoint
        {
            /// var Vector.sum:T { get }
            /// ?   where T:BinaryFloatingPoint 
            ///     The sum of all elements of this vector.
            /// #   (1:vector-horizontal-operations)
            var sum:T 
            {
                self.storage.sum()
            }
        }
        
        // element-wise operations
        extension Vector where T:FixedWidthInteger
        """
        Source.block 
        {
            let operators:[(vended:String, base:String, prose:String, topic:String)] =
            [
                ("|", "|",      "bitwise *or*",             "vector-bitwise-operations"),
                ("&", "&",      "bitwise *and*",            "vector-bitwise-operations"),
                ("^", "^",      "bitwise *xor*",            "vector-bitwise-operations"),
                
                ("&<<", "&<<",  "masked left-shift",        "vector-elementwise-binary-operations"),
                ("&>>", "&>>",  "masked right-shift",       "vector-elementwise-binary-operations"),
                
                ("+", "&+",     "wrapping addition",        "vector-elementwise-arithmetic"),
                ("-", "&-",     "wrapping subtraction",     "vector-elementwise-arithmetic"),
                ("*", "&*",     "wrapping multiplication",  "vector-elementwise-arithmetic"),
                ("/", "/",      "division",                 "vector-elementwise-arithmetic"),
                ("%", "%",      "remainder",                "vector-elementwise-arithmetic"),
            ]
            for (vended, base, prose, topic):(String, String, String, String) in operators
            {
                """
                /// static func Vector.(\(vended))(lhs:rhs:)
                /// ?   where T:FixedWidthInteger
                ///     Returns the elementwise result of a \(prose) operation on 
                ///     the given vectors.
                /// - lhs   :Self 
                /// - rhs   :Self 
                /// - ->    :Self 
                ///     The elementwise result of a \(prose) operation on 
                ///     `lhs` and `rhs`.
                /// #   (1:\(topic))
                static 
                func \(vended) (lhs:Self, rhs:Self) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs.storage)
                }
                /// static func Vector.(\(vended))(lhs:scalar:)
                /// ?   where T:FixedWidthInteger
                ///     Returns the elementwise result of a \(prose) operation on 
                ///     the given vector, and the vector obtained by broadcasting 
                ///     the given scalar.
                /// - lhs   :Self 
                /// - scalar:T 
                /// - ->    :Self 
                ///     The elementwise result of a \(prose) operation on 
                ///     `lhs` and `scalar`.
                /// #   (1:\(topic))
                static 
                func \(vended) (lhs:Self, scalar:T) -> Self 
                {
                    .init(storage: lhs.storage \(base) scalar)
                }
                /// static func Vector.(\(vended))(scalar:rhs:)
                /// ?   where T:FixedWidthInteger
                ///     Returns the elementwise result of a \(prose) operation on 
                ///     the vector obtained by broadcasting the given scalar, and 
                ///     the given vector.
                /// - scalar:T 
                /// - rhs   :Self 
                /// - ->    :Self 
                ///     The elementwise result of a \(prose) operation on 
                ///     `scalar` and `rhs`.
                /// #   (1:\(topic))
                static 
                func \(vended) (scalar:T, rhs:Self) -> Self 
                {
                    .init(storage: scalar \(base) rhs.storage)
                }
                """
            }
            for (vended, base, prose, topic):(String, String, String, String) in operators
            {
                """
                /// static func Vector.(\(vended)=)(lhs:rhs:)
                /// ?   where T:FixedWidthInteger
                ///     Performs an elementwise \(prose) operation on 
                ///     the given vectors, storing the result in `&lhs`.
                /// - lhs   :inout Self 
                /// - rhs   :Self 
                /// #   (1:\(topic))
                static 
                func \(vended)= (lhs:inout Self, rhs:Self)  
                {
                    lhs.storage \(base)= rhs.storage
                }
                /// static func Vector.(\(vended)=)(lhs:scalar:)
                /// ?   where T:FixedWidthInteger
                ///     Performs an elementwise \(prose) operation on 
                ///     the given vector, and the vector obtained by broadcasting 
                ///     the given scalar, storing the result in `&lhs`.
                /// - lhs   :inout Self 
                /// - scalar:T 
                /// #   (1:\(topic))
                static 
                func \(vended)= (lhs:inout Self, scalar:T)  
                {
                    lhs.storage \(base)= scalar
                }
                """
            }
            // miscellaneous 
            """
            /// static prefix func Vector.(~)(rhs:)
            /// ?   where T:FixedWidthInteger
            ///     Returns the elementwise result of a bitwise *not* operation 
            ///     on the given vector.
            /// - rhs   :Self 
            /// - ->    :Self 
            ///     A vector where each element contains the result of a
            ///     bitwise *not* operation on the corresponding element of `rhs`.
            /// #   (0:vector-bitwise-operations)
            static prefix
            func ~ (self:Self) -> Self 
            {
                .init(storage: ~self.storage)
            }
            
            /// static var Vector.leadingZeroBitCount:Self { get }
            /// ?   where T:FixedWidthInteger
            ///     A vector where each element contains the number of leading 
            ///     zero bits in the corresponding element of this vector.
            /// #   (0:vector-binary-representation-usage)
            var leadingZeroBitCount:Self 
            {
                .init(storage: self.storage.leadingZeroBitCount)
            }
            /// static var Vector.nonzeroBitCount:Self { get }
            /// ?   where T:FixedWidthInteger
            ///     A vector where each element contains the number of non-zero 
            ///     bits in the corresponding element of this vector.
            /// #   (0:vector-binary-representation-usage)
            var nonzeroBitCount:Self 
            {
                .init(storage: self.storage.nonzeroBitCount)
            }
            /// static var Vector.trailingZeroBitCount:Self { get }
            /// ?   where T:FixedWidthInteger
            ///     A vector where each element contains the number of trailing 
            ///     zero bits in the corresponding element of this vector.
            /// #   (0:vector-binary-representation-usage)
            var trailingZeroBitCount:Self 
            {
                .init(storage: self.storage.leadingZeroBitCount)
            }
            """
        }
        """
        extension Vector where T:BinaryFloatingPoint
        """
        Source.block 
        {
            let operators:[(vended:String, base:String, prose:String)] =
            [
                ("+", "+", "sum"),
                ("-", "-", "difference"),
                ("*", "*", "product"),
                ("/", "/", "quotient")
            ]
            for (vended, base, prose):(String, String, String) in operators
            {
                """
                /// static func Vector.(\(vended))(lhs:rhs:)
                /// ?   where T:BinaryFloatingPoint
                ///     Returns the elementwise \(prose) of the given vectors.
                /// - lhs   :Self 
                /// - rhs   :Self 
                /// - ->    :Self 
                ///     The elementwise \(prose) of `lhs` and `rhs`.
                /// #   (1:vector-elementwise-arithmetic)
                static 
                func \(vended) (lhs:Self, rhs:Self) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs.storage)
                }
                /// static func Vector.(\(vended))(lhs:scalar:)
                /// ?   where T:BinaryFloatingPoint
                ///     Returns the elementwise \(prose) of the given vector, and 
                ///     the vector obtained by broadcasting the given scalar.
                /// - lhs   :Self 
                /// - scalar:T 
                /// - ->    :Self 
                ///     The elementwise \(prose) of `lhs` and the vector obtained 
                ///     by broadcasting `scalar`.
                /// #   (1:vector-elementwise-arithmetic)
                static 
                func \(vended) (lhs:Self, scalar:T) -> Self 
                {
                    .init(storage: lhs.storage \(base) scalar)
                }
                /// static func Vector.(\(vended))(scalar:rhs:)
                /// ?   where T:BinaryFloatingPoint
                ///     Returns the elementwise \(prose) of the vector obtained 
                ///     by broadcasting the given scalar, and the given vector.
                /// - scalar:Self 
                /// - rhs   :Self 
                /// - ->    :Self 
                ///     The elementwise \(prose) of the vector obtained 
                ///     by broadcasting `scalar`, and `rhs`.
                /// #   (1:vector-elementwise-arithmetic)
                static 
                func \(vended) (scalar:T, rhs:Self) -> Self 
                {
                    .init(storage: scalar \(base) rhs.storage)
                }
                """
            }
            for (vended, base, prose):(String, String, String) in operators
            {
                """
                /// static func Vector.(\(vended)=)(lhs:rhs:)
                /// ?   where T:BinaryFloatingPoint
                ///     Stores the elementwise \(prose) of the given vectors in 
                ///     `&lhs`.
                /// - lhs   :inout Self 
                /// - rhs   :Self 
                /// #   (1:vector-elementwise-arithmetic)
                static 
                func \(vended)= (lhs:inout Self, rhs:Self)  
                {
                    lhs.storage \(base)= rhs.storage
                }
                /// static func Vector.(\(vended)=)(lhs:scalar:)
                /// ?   where T:BinaryFloatingPoint
                ///     Stores the elementwise \(prose) of the given vector and 
                ///     the vector obtained by broadcasting `scalar` in `&lhs`.
                /// - lhs   :inout Self 
                /// - scalar:T 
                /// #   (1:vector-elementwise-arithmetic)
                static 
                func \(vended)= (lhs:inout Self, scalar:T)  
                {
                    lhs.storage \(base)= scalar
                }
                """
            }
            // miscellaneous
            """
            /// static prefix func Vector.(-)(rhs:)
            /// ?   where T:BinaryFloatingPoint
            ///     Negates the given vector. 
            /// - rhs   :Self 
            /// #   (0:vector-elementwise-arithmetic)
            static prefix
            func - (rhs:Self) -> Self 
            {
                .init(storage: -rhs.storage)
            }
            /// func Vector.addingProduct(_:_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Returns the elementwise sum of this vector, and the 
            ///     elementwise product of the two given vectors, in a single 
            ///     fused-multiply operation.
            /// - a :Self 
            /// - b :Self 
            /// - ->:Self 
            ///     The elementwise sum of this vector, and the elementwise 
            ///     product of `a` and `b`.
            /// #   (2:vector-elementwise-arithmetic)
            func addingProduct(_ a:Self, _ b:Self) -> Self 
            {
                .init(storage: self.storage.addingProduct(a.storage, b.storage))
            }
            /// func Vector.addingProduct(_:_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Returns the elementwise sum of this vector, and the given 
            ///     vector scaled by the given scalar value, in a single 
            ///     fused-multiply operation.
            /// - a :Self 
            /// - b :T 
            /// - ->:Self 
            ///     The elementwise sum of this vector, and `a` scaled by `b`.
            /// #   (2:vector-elementwise-arithmetic)
            func addingProduct(_ a:Self, _ b:T) -> Self 
            {
                .init(storage: self.storage.addingProduct(a.storage, b))
            }
            /// func Vector.addingProduct(_:_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Returns the elementwise sum of this vector, and the given 
            ///     vector scaled by the given scalar value, in a single 
            ///     fused-multiply operation.
            /// - a :T 
            /// - b :Self 
            /// - ->:Self 
            ///     The elementwise sum of this vector, and `b` scaled by `a`.
            /// #   (2:vector-elementwise-arithmetic)
            func addingProduct(_ a:T, _ b:Self) -> Self 
            {
                .init(storage: self.storage.addingProduct(a, b.storage))
            }
            /// mutating func Vector.addProduct(_:_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Adds each element of the elementwise product of the two given 
            ///     vectors to the corresponding element of this vector, in a single 
            ///     fused-multiply operation.
            /// - a :Self 
            /// - b :Self 
            /// #   (2:vector-elementwise-arithmetic)
            mutating 
            func addProduct(_ a:Self, _ b:Self) 
            {
                self.storage.addProduct(a.storage, b.storage)
            }
            /// mutating func Vector.addProduct(_:_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Adds each element of the given vector scaled by the given scalar 
            ///     value to the corresponding element of this vector, in a single 
            ///     fused-multiply operation.
            /// - a :Self 
            /// - b :T 
            /// #   (2:vector-elementwise-arithmetic)
            mutating 
            func addProduct(_ a:Self, _ b:T) 
            {
                self.storage.addProduct(a.storage, b)
            }
            /// mutating func Vector.addProduct(_:_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Adds each element of the given vector scaled by the given scalar 
            ///     value to the corresponding element of this vector, in a single 
            ///     fused-multiply operation.
            /// - a :T 
            /// - b :Self 
            /// #   (2:vector-elementwise-arithmetic)
            mutating 
            func addProduct(_ a:T, _ b:Self) 
            {
                self.storage.addProduct(a, b.storage)
            }
            
            /// func Vector.rounded(_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Returns this vector, rounded according to the given rounding rule. 
            /// - rule  :FloatingPointRoundingRule 
            ///     The rounding rule to use. The default value is
            ///     [`FloatingPointRoundingRule`toNearestOrAwayFromZero`].
            /// - ->    :Self 
            ///     A vector where each element is obtained by rounding the corresponding 
            ///     element of this vector according to `rule`.
            /// #   (0:vector-rounding-usage)
            func rounded(_ rule:FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self 
            {
                .init(storage: self.storage.rounded(rule))
            }
            /// mutating func Vector.round(_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Rounds each element of this vector according to the given rounding rule. 
            /// - rule  :FloatingPointRoundingRule 
            ///     The rounding rule to use. The default value is
            ///     [`FloatingPointRoundingRule`toNearestOrAwayFromZero`].
            /// #   (0:vector-rounding-usage)
            mutating 
            func round(_ rule:FloatingPointRoundingRule = .toNearestOrAwayFromZero) 
            {
                self.storage.round(rule)
            }
            
            /// static func Vector.sqrt(_:)
            /// ?   where T:BinaryFloatingPoint
            ///     Returns the elementwise square root of the given vector.
            /// - vector:Self 
            ///     A vector.
            /// - ->    :Self 
            ///     The elementwise square root of `vector`.
            /// #   (0:vector-elementwise-elementary-functions)
            static 
            func sqrt(_ vector:Self) -> Self 
            {
                .init(storage: vector.storage.squareRoot())
            }
            
            /// struct Vector.LineSegment 
            /// :   Hashable
            /// ?   where T:BinaryFloatingPoint
            ///     A pair of vectors, which can be linearly interpolated.
            /// 
            ///     Create a line segment using the [`(Vector).(..)(_:_:)`] 
            ///     operator. 
            /// #   (1:vector-interpolation-usage)
            struct LineSegment:Hashable 
            {
                /// var Vector.LineSegment.start:Vector<Storage, T>
                ///     The starting point of this line segment.
                var start:Vector<Storage, T>
                /// var Vector.LineSegment.end:Vector<Storage, T>
                ///     The ending point of this line segment.
                var end:Vector<Storage, T>
                
                /// func Vector.LineSegment.callAsFunction(_:)
                ///     Interpolates between the endpoints of this line segment 
                ///     by the given parameter. 
                /// 
                ///     Calling this method is equivalent to writing 
                ///     the code `(self.start * (1 - t)).addingProduct(self.end, t)`.
                /// - t :T
                ///     The interpolation parameter. It is acceptable to pass 
                ///     values less than `0`, or greater than `1`.
                /// - ->:Vector<Storage, T>
                ///     A vector obtained by linearly interpolating the endpoints 
                ///     of this line segment by `t`. 
                /// #   (2:vector-interpolation-usage)
                func callAsFunction(_ t:T) -> Vector<Storage, T>
                {
                    (self.start * (1 - t)).addingProduct(self.end, t)
                }
            }
            
            /// static func Vector.(..)(_:_:) 
            /// ?   where T:BinaryFloatingPoint
            ///     Creates a line segment from two endpoints. 
            /// 
            ///     There are no restrictions on the endpoint vectors.
            /// - start :Self
            ///     The starting point.
            /// - end   :Self
            ///     The ending point.
            /// - ->    :LineSegment 
            ///     A line segment.
            /// #   (0:vector-interpolation-usage)
            static 
            func .. (_ start:Self, _ end:Self) -> LineSegment
            {
                .init(start: start, end: end)
            } 
            """
        }
        """
        extension Vector where Storage:SIMD.Transposable, T:Numerics.Real 
        """
        Source.block 
        {
            for function:String in ["sin", "cos", "tan", "asin", "acos", "atan", "exp", "log"] 
            {
                """
                /// static func Vector.\(function)(_:)
                /// ?   where Storage:SIMD.Transposable, T:Numerics.Real
                ///     Returns the elementwise `\(function)` of the given vector. 
                /// 
                ///     **Note:** This function is not SIMD-vectorized; it is 
                ///     implemented through scalar operations.
                /// - vector:Self 
                ///     A vector. 
                /// - ->    :Self 
                ///     The elementwise `\(function)` of `vector`.
                /// #   (1:vector-elementwise-elementary-functions)
                static 
                func \(function)(_ vector:Self) -> Self 
                {
                    vector.map(T.\(function)(_:))
                }
                """
            }
        }
        """
        
        // geometric operations
        """
        for domain:String in numeric 
        {
            """
            extension Vector where T:\(domain)
            """
            Source.block 
            {
                """
                /// static func Vector.(<>)(lhs:rhs:) 
                /// ?   where T:\(domain)
                """
                if domain == "FixedWidthInteger"
                {
                    """
                    ///     Returns the dot product of the given vectors, with 
                    ///     two’s-complement wraparound if the result is not 
                    ///     representable by [[`T`]].
                    """
                }
                else 
                {
                    """
                    ///     Returns the dot product of the given vectors.
                    """
                }
                """
                /// - lhs   :Self
                /// - rhs   :Self
                /// - ->    :T 
                ///     The dot product of `lhs` and `rhs`.
                /// #   (0:vector-linear-operations)
                static 
                func <> (lhs:Self, rhs:Self) -> T 
                {
                    (lhs * rhs).sum
                }
                """
                if domain == "BinaryFloatingPoint" 
                {
                    """
                    
                    /// var Vector.norm:T { get }
                    /// ?   where T:\(domain)
                    ///     The scalar norm of this vector.
                    /// 
                    ///     Calling this property is equivalent to writing the 
                    ///     code `(self <> self).squareRoot()`.
                    /// #   (0:vector-normalization-usage)
                    var norm:T 
                    {
                        (self <> self).squareRoot() 
                    }
                    /// func Vector.normalized()
                    /// ?   where T:\(domain)
                    ///     Returns a unit-length vector in the same direction 
                    ///     as this vector. 
                    /// 
                    ///     The [`norm`] of this vector must be non-zero.
                    /// - ->:Self
                    ///     A unit-length vector obtained by dividing the elements 
                    ///     of this vector by [`norm`].
                    /// #   (1:vector-normalization-usage)
                    func normalized() -> Self
                    {
                        self / self.norm 
                    }
                    /// mutating func Vector.normalize()
                    /// ?   where T:\(domain)
                    ///     Normalizes this vector to a unit-length vector in 
                    ///     the same direction.
                    /// 
                    ///     The [`norm`] of this vector must be non-zero.
                    /// #   (1:vector-normalization-usage)
                    mutating 
                    func normalize() 
                    {
                        self /= self.norm 
                    }
                    
                    /// static func Vector.(~<)(lhs:radius:)
                    /// ?   where T:\(domain)
                    ///     Returns a boolean value indicating if the given vector 
                    ///     is contained by the sphere with the given radius, 
                    ///     centered on the origin, *not* including the sphere 
                    ///     boundary.
                    /// 
                    ///     Calling this operator is more efficient than taking 
                    ///     the [`norm`] of `lhs` and comparing it with `radius`.
                    /// - lhs   :Self
                    ///     A vector to test for sphere membership.
                    /// - radius:T 
                    ///     The radius of the sphere to test for membership in.
                    /// - ->    :Bool 
                    ///     `true` if `lhs` is strictly inside the specified 
                    ///     sphere; `false` otherwise.
                    /// #   (1:vector-region-test-usage)
                    static 
                    func ~< (lhs:Self, radius:T) -> Bool 
                    {
                        lhs <> lhs <  radius * radius 
                    }
                    /// static func Vector.(~~)(lhs:radius:)
                    /// ?   where T:\(domain)
                    ///     Returns a boolean value indicating if the given vector 
                    ///     is contained by the sphere with the given radius, 
                    ///     centered on the origin, *including* the sphere 
                    ///     boundary.
                    /// 
                    ///     Calling this operator is more efficient than taking 
                    ///     the [`norm`] of `lhs` and comparing it with `radius`.
                    /// 
                    ///     **Note:** Due to floating point precision error, 
                    ///     this operator may still indicate points on the sphere 
                    ///     boundary as being outside the sphere. Consider 
                    ///     adding a small epsilon-margin to `radius` to account 
                    ///     for this.
                    /// - lhs   :Self
                    ///     A vector to test for sphere membership.
                    /// - radius:T 
                    ///     The radius of the sphere to test for membership in.
                    /// - ->    :Bool 
                    ///     `true` if `lhs` is inside the specified sphere, or on 
                    ///     its boundary; `false` otherwise.
                    /// #   (1:vector-region-test-usage)
                    static 
                    func ~~ (lhs:Self, radius:T) -> Bool 
                    {
                        lhs <> lhs <= radius * radius 
                    }
                    /// static func Vector.(!~)(lhs:radius:)
                    /// ?   where T:\(domain)
                    ///     Returns a boolean value indicating if the given vector 
                    ///     is outside of the sphere with the given radius, 
                    ///     centered on the origin, or on the sphere 
                    ///     boundary.
                    /// 
                    ///     Calling this operator is more efficient than taking 
                    ///     the [`norm`] of `lhs` and comparing it with `radius`.
                    /// 
                    ///     **Note:** Due to floating point precision error, 
                    ///     this operator may still indicate points on the sphere 
                    ///     boundary as being inside the sphere. Consider 
                    ///     adding a small epsilon-margin to `radius` to account 
                    ///     for this.
                    /// - lhs   :Self
                    ///     A vector to test for sphere membership.
                    /// - radius:T 
                    ///     The radius of the sphere to test for membership in.
                    /// - ->    :Bool 
                    ///     `true` if `lhs` is outside the specified sphere, or on 
                    ///     its boundary; `false` otherwise.
                    /// #   (1:vector-region-test-usage)
                    static 
                    func !~ (lhs:Self, radius:T) -> Bool 
                    {
                        lhs <> lhs >= radius * radius 
                    }
                    /// static func Vector.(!>)(lhs:radius:)
                    /// ?   where T:\(domain)
                    ///     Returns a boolean value indicating if the given vector 
                    ///     is strictly outside of the sphere with the given radius, 
                    ///     centered on the origin.
                    /// 
                    ///     Calling this operator is more efficient than taking 
                    ///     the [`norm`] of `lhs` and comparing it with `radius`.
                    /// - lhs   :Self
                    ///     A vector to test for sphere membership.
                    /// - radius:T 
                    ///     The radius of the sphere to test for membership in.
                    /// - ->    :Bool 
                    ///     `true` if `lhs` is strictly outside the specified 
                    ///     sphere; `false` otherwise.
                    /// #   (1:vector-region-test-usage)
                    static 
                    func !> (lhs:Self, radius:T) -> Bool 
                    {
                        lhs <> lhs  > radius * radius 
                    }
                    """
                }
            }
        }
        """
        // cross product 
        extension Vector where Storage == SIMD2<T>, T:BinaryFloatingPoint 
        {
            /// static func Vector.(>|<)(lhs:rhs:) 
            /// ?   where Storage == SIMD2<T>, T:BinaryFloatingPoint
            ///     Returns the two-dimensional cross product of the given 
            ///     vectors.
            /// 
            ///     Calling this operator is roughly equivalent to computing the 
            ///     three-dimensional cross product of `lhs` and `rhs`, extended 
            ///     with a *z*-coordinate of zero, and taking the *z*-coordinate 
            ///     of the result. However, this operator computes the result using 
            ///     fewer operations than the three-dimensional implementation.
            /// - lhs   :Self 
            ///     The first vector.
            /// - rhs   :Self 
            ///     The second vector.
            /// - ->    :T 
            ///     The magnitude of the cross product of `lhs` and `rhs`.
            /// #   (0:vector-cross-products)
            static 
            func >|< (lhs:Self, rhs:Self) -> T
            {
                lhs.x * rhs.y - rhs.x * lhs.y
            }
        }
        extension Vector where Storage == SIMD3<T>, T:BinaryFloatingPoint 
        {
            /// static func Vector.(>|<)(lhs:rhs:) 
            /// ?   where Storage == SIMD3<T>, T:BinaryFloatingPoint
            ///     Returns the three-dimensional cross product of the given 
            ///     vectors.
            /// - lhs   :Self 
            ///     The first vector.
            /// - rhs   :Self 
            ///     The second vector.
            /// - ->    :T 
            ///     The cross product of `lhs` and `rhs`.
            /// #   (0:vector-cross-products)
            static 
            func >|< (lhs:Self, rhs:Self) -> Self
            {
                lhs[.yzx] * rhs[.zxy] 
                - 
                rhs[.yzx] * lhs[.zxy]
            }
        }
        
        // linear aggregates
        
        /// extension SIMD 
        
        /// protocol SIMD.Transposable
        /// :   SIMD 
        ///     An SIMD backing storage type which supports arbitrary elementwise 
        ///     transformations. 
        /// 
        ///     You can conform additional types to this protocol to add linear algebra 
        ///     support for 8-, 16-, etc. dimensional vectors. Only do this if you really 
        ///     know what you are doing.
        protocol _SIMDTransposable:SIMD 
        {
            /// associatedtype SIMD.Transposable.Transpose 
            /// required 
            ///     A type representing the transposed form of this vector storage 
            ///     type. 
            /// 
            ///     **Note:** When conforming additional types to [`Transposable`], 
            ///     we recommend setting this `associatedtype` to a tuple type with 
            ///     *n* elements of type [`(SIMD).Scalar`].
            associatedtype Transpose
            
            /// associatedtype SIMD.Transposable.Square 
            /// required 
            ///     A square matrix type which a type conforming to [`Transposable`] 
            ///     supports extracting the diagonal of. 
            associatedtype Square 
            
            /// func SIMD.Transposable.map(_:)
            /// required 
            ///     Applies the given transformation individually to each element 
            ///     in this vector storage instance.
            /// - transform :(Scalar) -> Scalar
            ///     An elementwise transformation. 
            /// - ->        :Self 
            ///     A vector storage instance containing the elements of the original 
            ///     vector storage transformed by `transform`.
            func map(_ transform:(Scalar) -> Scalar) -> Self 
            
            /// static func SIMD.Transposable.transpose(_:) 
            /// required
            /// - column:Self 
            /// - ->    :Transpose 
            static 
            func transpose(_ column:Self) -> Transpose 
            
            /// static func SIMD.Transposable.transpose(_:) 
            /// required
            /// - row   :Transpose 
            /// - ->    :Self
            static 
            func transpose(_ row:Transpose) -> Self
            
            /// static func SIMD.Transposable.diagonal(trimming:)
            ///     Extracts the diagonal from a square matrix.
            /// required 
            /// - matrix:Square 
            /// - ->    :Self
            static 
            func diagonal(trimming matrix:Square) -> Self 
            
            /// static func SIMD.Transposable.diagonal(padding:with:)
            ///     Creates a square matrix from a diagonal and a fill value.
            /// required 
            /// - diagonal  :Self 
            /// - fill      :Scalar 
            /// - ->        :Square
            static 
            func diagonal(padding diagonal:Self, with fill:Scalar) -> Square 
        }
        /// protocol SIMD.MatrixAlgebra 
        /// :   SIMD.Transposable 
        ///     An SIMD backing storage type which supports computing the determinant 
        ///     and inverse of an appropriately-sized matrix type.
        /// 
        ///     You can conform additional types to this protocol to add linear algebra 
        ///     support for additional matrix sizes. Only do this if you really 
        ///     know what you are doing.
        protocol _SIMDMatrixAlgebra:SIMD.Transposable 
        {
            /// static func SIMD.MatrixAlgebra.determinant(_:)
            /// required 
            ///     Computes the determinant of the given matrix.
            /// - matrix:Square 
            /// - ->    :Scalar 
            static 
            func determinant(_ matrix:Square) -> Scalar 
            
            /// static func SIMD.MatrixAlgebra.inverse(_:)
            /// required 
            ///     Computes the inverse of the given matrix.
            /// - matrix:Square 
            /// - ->    :Square 
            static 
            func inverse(_ matrix:Square) -> Square 
        }
        
        extension SIMD 
        {
            typealias Transposable  = _SIMDTransposable 
            typealias MatrixAlgebra = _SIMDMatrixAlgebra 
        }
        """
        for n:Int in 2 ... 4 
        {
            """
            /// extension SIMD\(n) 
            /// :   SIMD.Transposable 
            extension SIMD\(n):SIMD.Transposable 
            """
            Source.block 
            {
                """
                /// typealias SIMD\(n).Transpose = (\(repeatElement("Scalar", count: n).joined(separator: ", ")))
                /// ?:  SIMD.Transposable 
                typealias Transpose = (\(repeatElement("Scalar", count: n).joined(separator: ", ")))
                
                /// typealias SIMD\(n).Square = (\(repeatElement("Vector<Self, Scalar>", count: n).joined(separator: ", ")))
                /// ?:  SIMD.Transposable 
                typealias Square    = 
                """
                Source.block(delimiters: ("(", ")"))
                {
                    repeatElement("Vector<Self, Scalar>", count: n).joined(separator: ",\n")
                }
                """
                
                /// func SIMD\(n).map(_:) 
                /// ?:  SIMD.Transposable 
                /// - transform :(Scalar) -> Scalar 
                /// - ->        :Self 
                func map(_ transform:(Scalar) -> Scalar) -> Self 
                {
                    .init(\(components.cartesian.prefix(n)
                        .map{ "transform(self.\($0))" }
                        .joined(separator: ", ")))
                }
                
                /// static func SIMD\(n).transpose(_:) 
                /// ?:  SIMD.Transposable 
                /// - row   :Transpose
                /// - ->    :Self 
                static 
                func transpose(_ row:Transpose) -> Self
                {
                    .init(\((0 ..< n).map{ "row.\($0)" }.joined(separator: ", ")))
                } 
                /// static func SIMD\(n).transpose(_:) 
                /// - column:Self
                /// - ->    :Transpose
                static 
                func transpose(_ column:Self) -> Transpose 
                {
                    (\(components.cartesian.prefix(n).map{ "column.\($0)" }.joined(separator: ", ")))
                } 
                
                /// static func SIMD\(n).Transposable.diagonal(trimming:)
                /// ?:  SIMD.Transposable 
                /// - matrix:Square 
                /// - ->    :Self
                static 
                func diagonal(trimming matrix:Square) -> Self 
                {
                    .init(\(components.cartesian.prefix(n).enumerated()
                        .map{ "matrix.\($0.0).\($0.1)" }
                        .joined(separator: ", ")))
                }
                /// static func SIMD\(n).Transposable.diagonal(padding:with:)
                /// ?:  SIMD.Transposable 
                /// - diagonal  :Self 
                /// - fill      :Scalar 
                /// - ->        :Square
                static 
                func diagonal(padding diagonal:Self, with fill:Scalar) -> Square 
                """
                Source.block 
                {
                    Source.block(delimiters: ("(", ")"))
                    {
                        (0 ..< n).map
                        {
                            (j:Int) in 
                            """
                            .init(\(components.cartesian.prefix(n).enumerated()
                                .map{ $0.0 == j ? "diagonal.\($0.1)" : "fill" } 
                                .joined(separator: ", ")))
                            """
                        }.joined(separator: ",\n")
                    }
                }
            }
        }
        """
        /// extension SIMD2 
        /// :   SIMD.MatrixAlgebra 
        /// where Scalar:BinaryFloatingPoint 
        extension SIMD2:SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
        {
            /// static func SIMD2.determinant(_:)
            /// ?:  SIMD.Transposable where Scalar:BinaryFloatingPoint
            /// - A     :Square 
            /// - ->    :Scalar 
            static 
            func determinant(_ A:Square) -> Scalar 
            {
                A.0 >|< A.1
            }
            /// static func SIMD2.inverse(_:)
            /// ?:  SIMD.Transposable where Scalar:BinaryFloatingPoint
            /// - A     :Square 
            /// - ->    :Square 
            static 
            func inverse(_ A:Square) -> Square 
            {
                let column:(Vector<Self, Scalar>, Vector<Self, Scalar>)
                let determinant:Scalar = A.0 >|< A.1
                
                column.0 = .init( A.1.y, -A.0.y)
                column.1 = .init(-A.1.x,  A.0.x)
                
                return (column.0 / determinant, column.1 / determinant)
            }
        }
        /// extension SIMD3 
        /// :   SIMD.MatrixAlgebra 
        /// where Scalar:BinaryFloatingPoint 
        extension SIMD3:SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
        {
            /// static func SIMD3.determinant(_:)
            /// ?:  SIMD.Transposable where Scalar:BinaryFloatingPoint
            /// - A     :Square 
            /// - ->    :Scalar 
            static 
            func determinant(_ A:Square) -> Scalar 
            {
                A.0 >|< A.1 <> A.2
            }
            /// static func SIMD3.inverse(_:)
            /// ?:  SIMD.Transposable where Scalar:BinaryFloatingPoint
            /// - A     :Square 
            /// - ->    :Square 
            static 
            func inverse(_ A:Square) -> Square
            {
                let row:(Vector<Self, Scalar>, Vector<Self, Scalar>, Vector<Self, Scalar>)
                let determinant:Scalar 
                // can re-use this cross product computation 
                row.0       = A.1 >|< A.2
                row.1       = A.2 >|< A.0
                row.2       = A.0 >|< A.1 
                
                determinant = row.2 <> A.2
                
                return (row.0 / determinant, row.1 / determinant, row.2 / determinant)*
            }
        }
        """
        
        """
        extension Vector where Storage:SIMD.Transposable
        {
            /// typealias Vector.Row    = Storage.Transpose 
            /// ?   where Storage:SIMD.Transposable
            ///     A 1\\ ×\\ *n* matrix, where each column is an instance of [`T`].
            /// #   (0:vector-matrix-types)
            typealias Row       = Storage.Transpose
             
            /// typealias Vector.Matrix = Storage.Square  
            /// ?   where Storage:SIMD.Transposable
            ///     An *n*\\ ×\\ *n* matrix, where each column is an instance of [`Self`].
            /// #   (2:vector-matrix-types)
            typealias Matrix    = Storage.Square
            
            /// func Vector.map(_:)
            /// ?   where Storage:SIMD.Transposable
            ///     Returns a vector where each element is obtained by applying the 
            ///     given transformation over the corresponding element of this vector. 
            /// - transform :(T) -> T
            ///     An elementwise transformation. 
            /// - ->        :Self 
            ///     A vector instance containing the elements of this vector 
            ///     transformed by `transform`.
            /// #   (0:vector-map)
            func map(_ transform:(T) -> T) -> Self 
            {
                .init(storage: self.storage.map(transform))
            }
        }
        extension Vector:CustomStringConvertible where Storage:SIMD.Transposable
        {
            /// var Vector.description:String { get }
            /// ?:  CustomStringConvertible where Storage:SIMD.Transposable
            ///     A textual representation of this vector.
            var description:String 
            {
                "Vector\\(Storage.transpose(self.storage))"
            }
        }
        extension Vector 
        """
        Source.block 
        {
            for m:Int in 2 ... 4 
            {
                """
                /// typealias Vector.Matrix\(m) = (\(repeatElement("Self", count: m).joined(separator: ", "))) 
                ///     An *n*\\ ×\\ \(m) matrix, where each column is an instance of [`Self`].
                /// #   (1:vector-matrix-types)
                typealias Matrix\(m) = (\(repeatElement("Self", count: m).joined(separator: ", ")))
                """
            }
            
            """
            
            /// struct Vector.Diagonal
            /// :   Hashable 
            ///     An *n*\\ ×\\ *n* diagonal matrix. 
            /// 
            ///     Use this type to perform efficient matrix row- and column-scaling. 
            /// #   (3:vector-matrix-types)
            struct Diagonal:Hashable 
            {
                fileprivate 
                var diagonal:Vector<Storage, T> 
            }
            
            /// static func Vector.diagonal(_:)
            ///     Boxes an *n*-element vector as an *n*\\ ×\\ *n* diagonal matrix. 
            /// - diagonal  :Self 
            /// - ->        :Diagonal
            static 
            func diagonal(_ diagonal:Self) -> Diagonal  
            {
                .init(diagonal: diagonal)
            }
            /// static func Vector.diagonal(_:)
            ///     Unboxes an *n*-element vector from an *n*\\ ×\\ *n* diagonal matrix. 
            /// - diagonal  :Diagonal
            /// - ->        :Self
            static 
            func diagonal(_ diagonal:Diagonal) -> Self  
            {
                diagonal.diagonal
            }
            """
        }
        
        """
        
        """
        for n:Int in 2 ... 4 
        {
            """
            /// typealias Vector\(n)<T> = Vector<SIMD\(n), T>
            /// where T:SIMDScalar
            ///     A \(n)-element vector.
            /// #   (0:vector-fixed-length-specializations)
            typealias Vector\(n)<T> = Vector<SIMD\(n)<T>, T> where T:SIMDScalar
            """
        }
        
        """
        
        // transpose operator 
        """
        for n:Int in 2 ... 4 
        {
            let components:ArraySlice<String> = components.cartesian.prefix(n)
            """
            postfix 
            func * <T>(row:Vector\(n)<T>.Row) -> Vector\(n)<T>
                where T:SIMDScalar
            {
                .init(storage: SIMD\(n)<T>.transpose(row))
            } 
            
            postfix 
            func * <T>(column:Vector\(n)<T>) -> Vector\(n)<T>.Row
                where T:SIMDScalar
            {
                SIMD\(n)<T>.transpose(column.storage)
            } 
            """
            for m:Int in 2 ... 4 
            {
                """
                postfix 
                func * <T>(columns:Vector\(n)<T>.Matrix\(m)) -> Vector\(m)<T>.Matrix\(n)
                    where T:SIMDScalar
                """
                Source.block 
                {
                    Source.block(delimiters: ("(", ")"))
                    {
                        components.map 
                        {
                            (c:String) in 
                            "Vector\(m)<T>.init(\((0 ..< m).map{ "columns.\($0).\(c)" }.joined(separator: ", ")))"
                        }.joined(separator: ",\n")
                    }
                }
            } 
        }
        """
        
        // linear operations 
        """
        for domain:String in numeric 
        {
            """
            
            // vector outer product
            extension Vector where T:\(domain)
            """
            Source.block 
            {
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func >< (lhs:Self, rhs:Vector\(m)<T>.Row) -> Self.Matrix\(m) 
                    """
                    Source.block 
                    {
                        "(\((0 ..< m).map{ "lhs * rhs.\($0)" }.joined(separator: ", ")))"
                    }
                }
            }
            
            for n:Int in 2 ... 4 
            {
                let components:ArraySlice<String> = components.cartesian.prefix(n)
                """
                // matrix-vector product
                extension Vector where T:\(domain), Storage == SIMD\(n)<T>
                """
                Source.block 
                {
                    """
                    @available(*, unavailable, message: "outer product of row vector `lhs` and column vector `rhs` is better expressed as the inner product `lhs* <> rhs`")
                    static 
                    func >< (lhs:Self.Row, rhs:Self) -> T
                    {
                        fatalError()
                    }
                    
                    static 
                    func >< <Column>(lhs:Vector<Column, T>.Matrix\(n), rhs:Self) 
                        -> Vector<Column, T> 
                        where Column.Scalar == T
                    """
                    Source.block 
                    {
                        components.enumerated().map
                        { 
                            "(lhs.\($0.0) * rhs.\($0.1) as Vector<Column, T>)" 
                        }.joined(separator: "\n+\n")
                    }
                }
                """
                // matrix-matrix product 
                """
                for m:Int in 2 ... 4 
                {
                    """
                    func >< <T>(lhs:Vector\(n)<T>.Row, rhs:Vector\(n)<T>.Matrix\(m)) 
                        -> Vector\(m)<T>.Row
                        where T:\(domain)
                    """
                    Source.block 
                    {
                        """
                        let lhs:Vector\(n)<T> = lhs*
                        return (\((0 ..< m).map{ "lhs <> rhs.\($0)" }.joined(separator: ", ")))
                        """
                    }
                }
                for m:Int in 2 ... 4 
                {
                    """
                    func >< <Column, T>(lhs:Vector<Column, T>.Matrix\(n), rhs:Vector\(n)<T>.Matrix\(m)) 
                        -> Vector<Column, T>.Matrix\(m) 
                        where Column.Scalar == T, T:\(domain)
                    """
                    Source.block 
                    {
                        "(\((0 ..< m).map{ "lhs >< rhs.\($0)" }.joined(separator: ", ")))"
                    }
                }
            } 
            """
            // row scaling
            extension Vector.Diagonal where T:\(domain), Storage:SIMD.Transposable
            {
                @available(*, unavailable, message: "outer product of diagonal matrix `lhs` and row vector `rhs` is better expressed as the element-wise product `Vector.diagonal(lhs) * (rhs*)`")
                static 
                func >< (lhs:Self, rhs:Vector<Storage, T>.Row) 
                    -> Vector<Storage, T>.Row
                {
                    fatalError()
                }
            }
            extension Vector.Diagonal where T:\(domain)
            """
            Source.block 
            {
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func >< (lhs:Self, rhs:Vector<Storage, T>.Matrix\(m)) 
                        -> Vector<Storage, T>.Matrix\(m) 
                    """
                    Source.block
                    {
                        "(\((0 ..< m).map{ "lhs.diagonal * rhs.\($0)" }.joined(separator: ", ")))"
                    }
                }
            }
            """
            // column scaling
            extension Vector.Diagonal where T:\(domain), Storage:SIMD.Transposable
            {
                @available(*, unavailable, message: "outer product of row vector `lhs` and diagonal matrix `rhs` is better expressed as the element-wise product `(lhs*) * Vector.diagonal(rhs)`")
                static 
                func >< (lhs:Vector<Storage, T>.Row, rhs:Self) 
                    -> Vector<Storage, T>.Row
                {
                    fatalError()
                }
            }
            """
            for m:Int in 2 ... 4 
            {
                """
                extension Vector.Diagonal where T:\(domain), Storage == SIMD\(m)<T>
                """
                Source.block 
                {
                    """
                    static 
                    func >< (lhs:Vector<Storage, T>.Matrix\(m), rhs:Self) 
                        -> Vector<Storage, T>.Matrix\(m) 
                    """
                    Source.block
                    {
                        """
                        (\(components.cartesian.prefix(m).enumerated()
                            .map{ "lhs.\($0.0) * rhs.diagonal.\($0.1)" }
                            .joined(separator: ", ")))
                        """
                    }
                }
            }
        }
        """
        
        // matrix operations
        extension Vector where Storage:SIMD.Transposable
        {
            static 
            func diagonal(trimming matrix:Matrix) -> Self 
            {
                .init(storage: Storage.diagonal(trimming: matrix))
            } 
            static 
            func diagonal(padding diagonal:Self, with fill:T) -> Matrix 
            {
                Storage.diagonal(padding: diagonal.storage, with: fill)
            } 
        }
        extension Vector where Storage:SIMD.Transposable, T:Numeric 
        {
            static 
            func diagonal(padding diagonal:Self) -> Matrix 
            {
                Self.diagonal(padding: diagonal, with: .zero)
            } 
        }
        """
        for domain:String in numeric 
        {
            """
            extension Vector where Storage:SIMD.Transposable, T:\(domain) 
            {
                static 
                func trace(_ matrix:Matrix) -> T 
                {
                    Self.diagonal(trimming: matrix).sum
                }
            }
            """
        }
        for domain:String in numeric 
        {
            """
            extension Vector where T:\(domain) 
            {
                static 
                func trace(_ diagonal:Diagonal) -> T 
                {
                    Self.diagonal(diagonal).sum
                }
            }
            """
        }
        """
        extension Vector where Storage:SIMD.MatrixAlgebra 
        {
            static 
            func determinant(_ matrix:Matrix) -> T 
            {
                Storage.determinant(matrix)
            }
            static 
            func inverse(_ matrix:Matrix) -> Matrix 
            {
                Storage.inverse(matrix)
            }
        }
        """
        """
        
        // length-dependent + cross-type functionality
        """
        for n:Int in 2 ... 4 
        {
            let components:ArraySlice<String> = components.cartesian.prefix(n)
            """
            
            // initializers 
            extension Vector where Storage == SIMD\(n)<T>
            """
            Source.block 
            {
                Self.initializers(n: n, components: components)
                if n < 4 
                {
                    """
                    
                    // homogenization 
                    static 
                    func || (body:Self, tail:T) -> Vector\(n + 1)<T> 
                    {
                        .init(body, tail)
                    }
                    """
                }
            }
            """
            
            // type conversions 
            extension Vector where Storage == SIMD\(n)<T>, T:FixedWidthInteger
            """
            Source.block
            {
                """
                init<U>(clamping other:Vector\(n)<U>) where U:FixedWidthInteger 
                {
                    self.init(storage: .init(clamping: other.storage))
                }
                init<U>(truncatingIfNeeded other:Vector\(n)<U>) where U:FixedWidthInteger 
                {
                    self.init(storage: .init(truncatingIfNeeded: other.storage))
                }
                
                init<U>(_ other:Vector\(n)<U>) 
                    where U:BinaryFloatingPoint
                {
                    self.init(storage: .init(other.storage))
                }
                init<U>(_ other:Vector\(n)<U>, rounding rule:FloatingPointRoundingRule) 
                    where U:BinaryFloatingPoint
                {
                    self.init(storage: .init(other.storage, rounding: rule))
                }
                
                """
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func cast<U>(clamping other:Vector\(n)<U>.Matrix\(m)) -> Matrix\(m) 
                        where U:FixedWidthInteger 
                    {
                        (\((0 ..< m).map{ ".init(clamping: other.\($0))" }.joined(separator: ", ")))
                    }
                    """
                }
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func cast<U>(truncatingIfNeeded other:Vector\(n)<U>.Matrix\(m)) -> Matrix\(m) 
                        where U:FixedWidthInteger 
                    {
                        (\((0 ..< m).map{ ".init(truncatingIfNeeded: other.\($0))" }.joined(separator: ", ")))
                    }
                    """
                }
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func cast<U>(_ other:Vector\(n)<U>.Matrix\(m)) -> Matrix\(m) 
                        where U:BinaryFloatingPoint 
                    {
                        (\((0 ..< m).map{ ".init(other.\($0))" }.joined(separator: ", ")))
                    }
                    """
                }
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func cast<U>(_ other:Vector\(n)<U>.Matrix\(m), rounding rule:FloatingPointRoundingRule) 
                        -> Matrix\(m) 
                        where U:BinaryFloatingPoint 
                    {
                        (\((0 ..< m).map{ ".init(other.\($0), rounding: rule)" }.joined(separator: ", ")))
                    }
                    """
                }
            }
            """
            extension Vector where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
            """
            Source.block
            {
                """
                init<U>(_ other:Vector\(n)<U>) where U:FixedWidthInteger
                {
                    self.init(storage: .init(other.storage))
                }
                init<U>(_ other:Vector\(n)<U>) where U:BinaryFloatingPoint
                {
                    self.init(storage: .init(other.storage))
                }
                
                """
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func cast<U>(_ other:Vector\(n)<U>.Matrix\(m)) -> Matrix\(m) 
                        where U:FixedWidthInteger 
                    {
                        (\((0 ..< m).map{ ".init(other.\($0))" }.joined(separator: ", ")))
                    }
                    """
                }
                for m:Int in 2 ... 4 
                {
                    """
                    static 
                    func cast<U>(_ other:Vector\(n)<U>.Matrix\(m)) -> Matrix\(m) 
                        where U:BinaryFloatingPoint 
                    {
                        (\((0 ..< m).map{ ".init(other.\($0))" }.joined(separator: ", ")))
                    }
                    """
                }
            }
            """
            // components and swizzle-subscripts
            extension Vector where Storage == SIMD\(n)<T>
            """
            Source.block 
            {
                for c:String in components
                {
                    """
                    var \(c):T
                    {
                        _read   { yield  self.storage.\(c) }
                        _modify { yield &self.storage.\(c) }
                    }
                    """
                }
                """
                
                """
                for m:Int in 2 ... 4 
                {
                    """
                    subscript<Index>(selector:Vector\(m)<Index>) -> Vector\(m)<T>
                        where Index:FixedWidthInteger & SIMDScalar 
                    {
                        .init(storage: self.storage[selector.storage])
                    }
                    """
                }
                for m:Int in 2 ... 4 
                {
                    """
                    subscript(swizzle:VectorSwizzle\(m)) -> Vector\(m)<T>
                    {
                        self[swizzle.selector]
                    }
                    """
                }
            }
            """
            // swizzle constants
            struct VectorSwizzle\(n):Hashable 
            """
            Source.block 
            {
                "var selector:Vector\(n)<UInt8>"
                
                for permutation:[Int] in Self.permutations(n)
                {
                    let name:String     = permutation.map{ components[$0] }.joined()
                    let indices:String  = permutation.map(String.init(_:)).joined(separator: ", ")
                    "static let \(name):Self = .init(selector: (\(indices))*)"
                }
            }
        }
        
        """
        
        // extra `Rectangle` functionality 
        """
        for domain:String in numeric 
        {
            """
            extension VectorFiniteRangeExpression where T:\(domain) 
            """
            Source.block 
            {
                """
                var zero:Self 
                {
                    .init(lowerBound: .zero, upperBound: .zero)
                }
                var size:Vector<Storage, T> 
                {
                    self.upperBound - self.lowerBound
                }
                """
                if domain == "BinaryFloatingPoint"
                {
                    """
                    var midpoint:Vector<Storage, T> 
                    {
                        0.5 * (self.lowerBound + self.upperBound)
                    }
                    """
                }
            }
        }
        """
        
        // type conversions 
        """
        for n:Int in 2 ... 4 
        {
            """
            extension VectorFiniteRangeExpression where Storage == SIMD\(n)<T>, T:FixedWidthInteger
            """
            Source.block
            {
                """
                init<Other:VectorFiniteRangeExpression, U>(clamping other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                {
                    self.init(
                        lowerBound: .init(clamping: other.lowerBound),
                        upperBound: .init(clamping: other.upperBound))
                }
                init<Other:VectorFiniteRangeExpression, U>(truncatingIfNeeded other:Other)
                    where Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                {
                    self.init(
                        lowerBound: .init(truncatingIfNeeded: other.lowerBound),
                        upperBound: .init(truncatingIfNeeded: other.upperBound))
                }
                
                init<Other:VectorFiniteRangeExpression, U>(_ other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:BinaryFloatingPoint
                {
                    self.init(
                        lowerBound: .init(other.lowerBound),
                        upperBound: .init(other.upperBound))
                }
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
                init<Other:VectorFiniteRangeExpression, U>(_ other:Other) 
                    where Other.Storage == SIMD\(n)<U>, U:FixedWidthInteger
                {
                    self.init(
                        lowerBound: .init(other.lowerBound),
                        upperBound: .init(other.upperBound))
                }
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
        
        // quaternion 
        struct Quaternion<T>:Hashable 
            where T:SIMDScalar & Numerics.Real & BinaryFloatingPoint
        {
            private(set)
            var composite:Vector4<T> 
            
            var real:T 
            {
                self.composite.w
            } 
            var imaginary:Vector3<T> 
            {
                self.composite[.xyz]
            }
            
            static 
            var identity:Self
            {
                .init(composite: (0, 0, 0, 1)*)
            }
            
            init(composite:Vector4<T>) 
            {
                self.composite = composite
            }
            
            init(from start:Vector3<T>, to end:Vector3<T>) 
            {
                let a:T         = (2 * (1 + start <> end)).squareRoot()
                self.composite  = start >|< end / a || 0.5 * a
            }
            
            init(axis:Vector3<T>, angle:T)
            {
                let half:T      = 0.5 * angle 
                self.composite  = T.sin(half) * axis || T.cos(half)
            }
            
            init<U>(_ other:Quaternion<U>) 
                where U:SIMDScalar & Numerics.Real & BinaryFloatingPoint
            {
                self.init(composite: .init(other.composite))
            }
            
            func normalized() -> Self
            {
                .init(composite: self.composite.normalized())
            }
            mutating 
            func normalize() 
            {
                self.composite.normalize()
            }
            
            static 
            postfix func * (_ quaternion:Self) -> Self
            {
                .init(composite: quaternion.composite * (-1, -1, -1, +1)*)
            }
        }
        """
    }
    
    @Source.Code 
    static 
    var swift:String 
    {
        Source.section(name: "vector.swift.part")
        {
            Self.code
        }
    }
}
