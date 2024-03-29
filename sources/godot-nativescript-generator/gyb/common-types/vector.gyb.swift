enum Vector 
{
    static 
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
    
    private static 
    func permutations(_ n:Int, k:Int) -> [[Int]] 
    {
        if k <= 0 
        {
            return [[]]
        }
        else 
        {
            return Self.permutations(n, k: k - 1).flatMap
            {
                (body:[Int]) -> [[Int]] in 
                (0 ..< n).map 
                {
                    (next:Int) -> [Int] in 
                    body + [next]
                }
            }
        }
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
                //[2, 1], // handled by generic SIMD.Extendable-driven initializer
                [1, 2],
            ]
        case 4:
            patterns = 
            [
                [2, 1, 1], 
                [1, 2, 1],
                [1, 1, 2],
                [2, 2],
                //[3, 1], // handled by generic SIMD.Extendable-driven initializer
                [1, 3],
            ]
        default:
            fatalError("unreachable")
        }
        
        return Source.fragment
        {
            """
            /// init Vector.init(\(repeatElement("_:", count: n).joined()))
            /// ?   where Storage == SIMD\(n)<T>
            ///     Creates a \(n)-element vector from scalar arguments. 
            /// 
            ///     > note:
            ///     Using the postfix [`(*)(row:)`] operator is the preferred 
            ///     form of expressing vector literals.
            """
            for component:String in components 
            {
                """
                /// - \(component):T
                """
            }
            """
            /// #   (1\(n):vector-initializer-usage)
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
                        let _:Void = containers.append("\(variable):T")
                        let _:Void = accessors.append(variable)
                    }
                    else 
                    {
                        let variable:String = components[index ..< index + count].joined()
                        let _:Void = containers.append("\(variable):Vector\(count)<T>")
                        
                        for component:String in components.prefix(count)
                        {
                            let _:Void = accessors.append("\(variable).\(component)")
                        }
                    }
                    
                    let _:Void = index += count 
                }
                """
                /// init Vector.init(\(repeatElement("_:", count: containers.count).joined()))
                /// ?   where Storage == SIMD\(n)<T> 
                ///     Creates a \(n)-element vector by concatenating vector and scalar arguments.
                """
                for container:String in containers 
                {
                    """
                    /// - \(container)
                    """
                }
                """
                /// #   (1\(n):vector-initializer-usage)
                init(\(containers.map{ "_ \($0)" }.joined(separator: ", "))) 
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
    static 
    var swift:String 
    {
        let numeric:[String] = ["FixedWidthInteger", "BinaryFloatingPoint"]
        
        """
        /// import Numerics 
        ///     The [*Swift Numerics*](https://github.com/apple/swift-numerics)
        ///     module.

        /// import protocol Numerics.Real
        ///     The [*Swift Numerics*](https://github.com/apple/swift-numerics) 
        ///     [`Real`](https://github.com/apple/swift-numerics/blob/main/Sources/RealModule/README.md)
        ///     protocol.
        
        import protocol Numerics.Real
        
        /// operator .. : RangeFormationPrecedence 
        ///     Represents an interpolation range expression.
        /// #   (-1:)
        
        /// operator <> : MultiplicationPrecedence 
        ///     Represents a dot- or inner-product operation.
        /// #   (3:)
        
        /// operator >|< : MultiplicationPrecedence 
        ///     Represents a cross-product operation.
        /// #   (2:)
        
        /// operator >< : MultiplicationPrecedence 
        ///     Represents a vector- or matrix-product operation.
        /// #   (4:)
        
        /// postfix operator * 
        ///     Represents a transpose operation. This operator can be used to 
        ///     express vectors and matrices as tuple literals.
        /// #   (1:)
        
        /// infix operator ~<  : ComparisonPrecedence 
        ///     Represents a region membership test.
        /// #   (5:)
        
        /// infix operator ~~  : ComparisonPrecedence 
        ///     Represents a region membership test.
        /// #   (5:)
        
        /// infix operator !~  : ComparisonPrecedence 
        ///     Represents a region membership test.
        /// #   (5:)
        
        /// infix operator !>  : ComparisonPrecedence 
        ///     Represents a region membership test.
        /// #   (5:)
        
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
        /// :   CustomStringConvertible 
        /// :   Godot.ArrayElement          where Storage:Godot.ArrayElementStorage 
        /// :   Godot.VariantRepresentable  where Storage:Godot.VectorStorage
        /// :   Godot.Variant               where Storage:Godot.VectorStorage, T == Float32 
        /// where Storage:SIMD, T:SIMDScalar, T == Storage.Scalar 
        ///     An SIMD-backed vector.
        /// 
        ///     Create a vector from a tuple literal using the postfix 
        ///     [`(*)(row:)`] operator: 
        /**     
                ```swift 
                let x:Vector4<Int> = (1, 2, 3, 4)*
                ```
        **/
        ///     Matrices are represented by tuples of vectors, where each vector 
        ///     forms a column of the matrix:
        /**     
                ```swift 
                let a:Vector3<Double>           = (1.0, 2.0, 3.0)*,
                    b:Vector3<Double>           = (3.0, 2.0, 1.5)*,
                    c:Vector3<Double>           = (2.0, 0.5, 2.0)*,
                    d:Vector3<Double>           = (0.0, 1.0, 2.0)*
                
                let A:Vector3<Double>.Matrix4   = (a, b, c, d)
                ```
        **/
        ///     You can extend vectors using the [`(Vector).(||)(prefix:tail:)`] 
        ///     operator, and perform matrix multiplications using one of the 
        ///     `><` operators. 
        /**     
                ```swift 
                let w:Vector3<Double>   = (0.5, 0.75, 1.0)* 
                let y:Vector3<Double>   =  A >< (w || 1.0)
                ```
        **/
        /// #   [Vector types](vector-fixed-length-specializations)
        /// #   [Matrix types](vector-matrix-types)
        /// #   [Creating vectors](vector-initializer-usage)
        /// #   [Converting vectors between scalar types](vector-type-conversion-usage)
        /// #   [Converting matrices between scalar types](vector-matrix-type-conversion-usage)
        /// #   [Working with SIMD backing storage](vector-simd-storage-usage)
        /// #   [Getting the string representation of a vector](vector-description-usage)
        /// #   [Accessing vector elements](vector-element-access)
        /// #   [Accessing vector swizzles](vector-swizzle-usage)
        /// #   [Transposing vectors](vector-transposition-usage)
        /// #   [Transposing matrices](vector-matrix-transposition-usage)
        /// #   [Transforming vectors](vector-transform-usage)
        /// #   [Vector constants](vector-constants)
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
        /// #   [Computing dot products](vector-dot-products)
        /// #   [Computing outer products](vector-outer-products)
        /// #   [Computing matrix-vector products](vector-matrix-vector-products)
        /// #   [Computing matrix-matrix products (two outputs)](vector-matrix-matrix-2-products)
        /// #   [Computing matrix-matrix products (three outputs)](vector-matrix-matrix-3-products)
        /// #   [Computing matrix-matrix products (four outputs)](vector-matrix-matrix-4-products)
        /// #   [Working with diagonal elements of a matrix](vector-matrix-diagonal-usage)
        /// #   [Working with diagonal matrices](vector-diagonal-usage)
        /// #   [Scaling the rows of a matrix](vector-matrix-row-scaling)
        /// #   [Scaling the columns of a matrix](vector-matrix-column-scaling)
        /// #   [Getting the inverse of a matrix](vector-matrix-inverse-usage)
        /// #   [Working with binary representation](vector-binary-representation-usage)
        /// #   [Using vector masks](vector-mask-usage)
        /// #   [Comparing vectors](vector-comparison-usage)
        /// #   [Working with affine planes](vector-plane)
        /// #   [Testing for region membership](vector-region-test-usage)
        /// #   (0:math-types)
        /// #   (20:godot-core-types)
        /// #   (20:)
        struct Vector<Storage, T>:Hashable 
            where Storage:SIMD, T:SIMDScalar, T == Storage.Scalar
        {
            /// struct Vector.Mask 
            ///     An SIMD-backed vector mask.
            /// #   [See also](vector-mask-usage)
            /// #   (0:vector-mask-usage)
            /// #   (0:math-types)
            struct Mask
            {
                /// var Vector.Mask.storage:SIMDMask<Storage.MaskStorage> 
                ///     The SIMD backing storage of this vector mask.
                var storage:SIMDMask<Storage.MaskStorage>
            }
            
            /// var Vector.storage:Storage 
            ///     The SIMD backing storage of this vector.
            /// #   (1:vector-simd-storage-usage)
            var storage:Storage 
            
            /// init Vector.init(storage:)
            ///     Creates a vector instance with the given SIMD data.
            /// - storage   :Storage 
            ///     An SIMD value.
            /// #   (0:vector-simd-storage-usage)
            init(storage:Storage)
            {
                self.storage = storage
            }
            
            /// subscript Vector[_:] { get set }
            ///     Accesses the element at the specified index.
            /// - index :Int 
            ///     The index of the element to access. It must be in the range `0 ..< n`, 
            ///     where `n` is the number of elements in this vector.
            /// - ->    :T
            /// #   (1:vector-element-access)
            /// #   (arity-1)
            subscript(index:Int) -> T 
            {
                _read   { yield  self.storage[index] }
                _modify { yield &self.storage[index] }
            }
        }
        extension Vector:CustomStringConvertible 
        {
            /// var Vector.description:String { get }
            /// ?:  CustomStringConvertible 
            ///     A textual representation of this vector.
            /// #   (vector-description-usage)
            var description:String 
            {
                "(\\(self.storage.indices.map{ "\\(self.storage[$0])" }.joined(separator: ", ")))*"
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
            /// #   (0:vector-initializer-usage)
            init(repeating value:T) 
            {
                self.init(storage: .init(repeating: value))
            }
            
            /// init Vector.init<Prefix>(_:_:)
            /// where Prefix:SIMD.Extendable, Prefix.Extended == Storage 
            ///     Creates an *n*-element vector by concatenating vector and scalar arguments.
            /// 
            ///     > note:
            ///     Using the [`(Vector).(||)(prefix:tail:)`]
            ///     operator is the preferred form of appending a scalar value 
            ///     to an (*n* – 1)-element vector.
            /// - prefix:Vector<Prefix, T> 
            /// - tail  :T 
            /// #   (-3:vector-initializer-usage)
            init<Prefix>(_ prefix:Vector<Prefix, T>, _ tail:T) 
                where Prefix:SIMD.Extendable, Prefix.Extended == Storage 
            {
                self = prefix || tail
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
            /// #   (0:vector-initializer-usage)
            init(to value:T, where mask:Mask, else empty:T = .zero) 
            {
                self.init(storage: .init(repeating: empty).replacing(with: value, where: mask.storage))
            }
        }
        extension Vector where Storage:SIMD.Extendable 
        {
            /// static func Vector.(||)(prefix:tail:)
            /// ?   where Storage:SIMD.Extendable
            ///     Appends the given scalar value to the given *n*-element 
            ///     vector instance, returning an (*n* + 1)-element vector.
            /// - prefix:Self 
            /// - tail  :T 
            /// - ->    :Vector<Storage.Extended, T> 
            ///     An (*n* + 1)-element vector with `prefix` in its first 
            ///     *n* positions, and `tail` in its last position.
            /// #   (-2:vector-initializer-usage)
            static 
            func || (prefix:Self, tail:T) -> Vector<Storage.Extended, T> 
            {
                .init(storage: prefix.storage.extended(with: tail))
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
            /// #   (1:vector-transform-usage)
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
            /// #   (1:vector-transform-usage)
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
            /// #   (1:vector-transform-usage)
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
            /// #   (1:vector-transform-usage)
            func replacing(with other:Self, where mask:Mask) -> Self
            {
                .init(storage: self.storage.replacing(with: other.storage, where: mask.storage))
            }
            
            /// func Vector.map(_:)
            ///     Returns a vector where each element is obtained by applying the 
            ///     given transformation over the corresponding element of this vector. 
            /// 
            ///     This method decomposes into scalar operations. Some operations, 
            ///     such as [`sqrt(_:)`], have SIMD-accelerated implementations 
            ///     which may be faster than calling this method with the 
            ///     corresponding scalar function.
            /// - transform :(T) -> T
            ///     An elementwise transformation. 
            /// - ->        :Self 
            ///     A vector instance containing the elements of this vector 
            ///     transformed by `transform`.
            /// #   (0:vector-transform-usage)
            func map(_ transform:(T) -> T) -> Self 
            {
                .init(storage: withoutActuallyEscaping(transform) 
                {
                    (transform:@escaping (T) -> T) in 
                    .init(self.storage.indices.lazy.map
                    {
                        transform(self.storage[$0])
                    } as LazyMapSequence<Range<Int>, T>)
                })
            }
        }
        
        // `Comparable`-related functionality
        extension Vector where T:Comparable
        """
        Source.block 
        {
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
            ///     > note:
            ///     Elements with the value `T.min` are mapped to 
            ///     the value `T.max`. All other values are transformed according 
            ///     to the mathematical definition of absolute value.
            /// 
            ///     > note:
            ///     To obtain the scalar magnitude of an integer vector, 
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
            ///     > note:
            ///     Elements with the value `T.min` will remain `T.min`, 
            ///     as the value `-T.min` is equivalent to `T.max` when truncated 
            ///     to the bit width of [[`T`]]. All other values are transformed according 
            ///     to the mathematical definition of absolute value.
            /// 
            ///     > note:
            ///     To obtain the scalar magnitude of an integer vector, 
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
            ///     > note:
            ///     To obtain the scalar magnitude of a vector, use the 
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
            /// #   (6:math-types)
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
                ///     the following code: 
                /** 
                        ```swift 
                        (self.start * (1 - t)).addingProduct(self.end, t)
                        ```
                **/
                /// - t :T
                ///     The interpolation parameter. It is acceptable to pass 
                ///     values less than `0`, or greater than `1`.
                /// - ->:Vector<Storage, T>
                ///     A vector obtained by linearly interpolating the endpoints 
                ///     of this line segment by `t`. 
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
        extension Vector where T:Numerics.Real 
        """
        Source.block 
        {
            for function:String in ["sin", "cos", "tan", "asin", "acos", "atan", "exp", "log"] 
            {
                """
                /// static func Vector.\(function)(_:)
                /// ?   where T:Numerics.Real
                ///     Returns the elementwise `\(function)` of the given vector. 
                /// 
                ///     > note:
                ///     This operation is not hardware-vectorized; it is 
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
                /// #   (0:vector-dot-products)
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
                    ///     > note:
                    ///     Due to floating point precision error, 
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
                    ///     > note:
                    ///     Due to floating point precision error, 
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
        /// func (>|<)<T>(lhs:rhs:) 
        /// where T:BinaryFloatingPoint
        ///     Returns the two-dimensional cross product of the given 
        ///     vectors.
        /// 
        ///     Calling this operator is roughly equivalent to computing the 
        ///     three-dimensional cross product of `lhs` and `rhs`, extended 
        ///     with a *z*-coordinate of zero, and taking the *z*-coordinate 
        ///     of the result. However, this operator computes the result using 
        ///     fewer operations than the three-dimensional implementation.
        /// - lhs   :Vector2<T> 
        ///     The first vector.
        /// - rhs   :Vector2<T> 
        ///     The second vector.
        /// - ->    :T 
        ///     The magnitude of the cross product of `lhs` and `rhs`.
        /// #   (0:vector-cross-products)
        func >|< <T>(lhs:Vector2<T>, rhs:Vector2<T>) -> T
            where T:BinaryFloatingPoint 
        {
            lhs.x * rhs.y - rhs.x * lhs.y
        }
        /// func (>|<)<T>(lhs:rhs:) 
        /// where T:BinaryFloatingPoint
        ///     Returns the three-dimensional cross product of the given 
        ///     vectors.
        /// - lhs   :Vector3<T> 
        ///     The first vector.
        /// - rhs   :Vector3<T> 
        ///     The second vector.
        /// - ->    :T 
        ///     The cross product of `lhs` and `rhs`.
        /// #   (0:vector-cross-products)
        func >|< <T>(lhs:Vector3<T>, rhs:Vector3<T>) -> Vector3<T>
            where T:BinaryFloatingPoint 
        {
            lhs[.yzx] * rhs[.zxy] 
            - 
            rhs[.yzx] * lhs[.zxy]
        }
        
        // linear aggregates
        extension Vector where Storage:SIMD.Transposable
        {
            /// typealias Vector.Row    = Storage.Transpose 
            /// ?   where Storage:SIMD.Transposable
            ///     A 1\\ ×\\ *n* matrix, where each column is an instance of [`T`].
            /// #   (0:vector-matrix-types)
            /// #   (2:math-types)
            typealias Row       = Storage.Transpose
             
            /// typealias Vector.Matrix = Storage.Square  
            /// ?   where Storage:SIMD.Transposable
            ///     An *n*\\ ×\\ *n* matrix, where each column is an instance of [`Self`].
            /// #   (2:vector-matrix-types)
            /// #   (2:math-types)
            typealias Matrix    = Storage.Square
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
                /// #   (3:math-types)
                typealias Matrix\(m) = (\(repeatElement("Self", count: m).joined(separator: ", ")))
                """
            }
            
            """
            
            /// struct Vector.Diagonal
            /// :   Hashable 
            ///     An *n*\\ ×\\ *n* diagonal matrix. 
            /// 
            ///     Use this type to perform efficient matrix row- and column-scaling. 
            /// #   [See also](vector-diagonal-usage)
            /// #   (3:vector-matrix-types)
            /// #   (4:math-types)
            struct Diagonal:Hashable 
            {
                fileprivate 
                var diagonal:Vector<Storage, T> 
            }
            
            /// static func Vector.diagonal(_:)
            ///     Boxes an *n*-element vector as an *n*\\ ×\\ *n* diagonal matrix. 
            /// - diagonal  :Self 
            /// - ->        :Diagonal
            /// #   (0:vector-diagonal-usage)
            static 
            func diagonal(_ diagonal:Self) -> Diagonal  
            {
                .init(diagonal: diagonal)
            }
            /// static func Vector.diagonal(_:)
            ///     Unboxes an *n*-element vector from an *n*\\ ×\\ *n* diagonal matrix. 
            /// - diagonal  :Diagonal
            /// - ->        :Self
            /// #   (0:vector-diagonal-usage)
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
            /// #   (1:math-types)
            typealias Vector\(n)<T> = Vector<SIMD\(n)<T>, T> where T:SIMDScalar
            """
        }
        
        """
        
        // transpose operator 
        
        /// postfix func (*)<Storage, T>(row:)
        /// where Storage:SIMD.Transposable, Storage.Scalar == T, T:SIMDScalar 
        ///     Creates an *n*-element vector from an *n*-element tuple.
        /// - row   :Vector<Storage, T>.Row 
        /// - ->    :Vector<Storage, T>
        /// #   (-1:vector-initializer-usage)
        postfix 
        func * <Storage, T>(row:Vector<Storage, T>.Row) -> Vector<Storage, T>
            where Storage:SIMD.Transposable, Storage.Scalar == T, T:SIMDScalar 
        {
            .init(storage: Storage.transpose(row))
        } 
        
        /// postfix func (*)<Storage, T>(column:)
        /// where Storage:SIMD.Transposable, Storage.Scalar == T, T:SIMDScalar 
        ///     Creates an *n*-element tuple from an *n*-element vector.
        /// - column:Vector<Storage, T>
        /// - ->    :Vector<Storage, T>.Row 
        /// #   (0:vector-transposition-usage)
        postfix 
        func * <Storage, T>(column:Vector<Storage, T>) -> Vector<Storage, T>.Row
            where Storage:SIMD.Transposable, Storage.Scalar == T, T:SIMDScalar 
        {
            Storage.transpose(column.storage)
        } 
        """
        for n:Int in 2 ... 4 
        {
            let components:ArraySlice<String> = Self.components.cartesian.prefix(n)
            for m:Int in 2 ... 4 
            {
                """
                /// postfix func (*)<T>(columns:)
                /// where T:SIMDScalar
                ///     Transposes a \(n)\\ ×\\ \(m) matrix, returning a \(m)\\ ×\\ \(n) matrix.
                /// - columns   :Vector\(n)<T>.Matrix\(m)
                /// - ->        :Vector\(m)<T>.Matrix\(n)
                /// #   (0:vector-matrix-transposition-usage)
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
                    /// static func Vector.(><)(column:row:)
                    ///     Computes the outer product of a column vector, and a row vector, 
                    ///     returning an *n*\\ ×\\ \(m) matrix.
                    /// - column:Self 
                    /// - row   :Vector\(m)<T>.Row 
                    /// - ->    :Matrix\(m)
                    /// #   (\(m):vector-outer-products)
                    static 
                    func >< (column:Self, row:Vector\(m)<T>.Row) -> Self.Matrix\(m) 
                    """
                    Source.block 
                    {
                        "(\((0 ..< m).map{ "column * row.\($0)" }.joined(separator: ", ")))"
                    }
                }
            }
            
            for n:Int in 2 ... 4 
            {
                """
                // matrix-vector product
                """
                let components:ArraySlice<String> = Self.components.cartesian.prefix(n)
                """
                @available(*, unavailable, message: "outer product of row vector `lhs` and column vector `rhs` is better expressed as the inner product `lhs* <> rhs`")
                func >< <T>(lhs:Vector\(n)<T>.Row, rhs:Vector\(n)<T>) -> T
                    where T:\(domain)
                {
                    fatalError()
                }
                
                /// func (><)<Column, T>(matrix:vector:)
                /// where Column:SIMD, Column.Scalar == T, T:\(domain)
                ///     Computes the matrix product of an *n*\\ ×\\ \(n) matrix, and 
                ///     an \(n)-element column vector, returning an *n*-element column vector.
                /// 
                ///     > note:
                ///     This operation is vectorized in the vertical direction, 
                ///     which means it is most efficient when the `matrix` type has more 
                ///     rows than columns.
                /// - matrix:Vector<Column, T>.Matrix\(n)
                /// - vector:Vector\(n)<T>
                /// - ->    :Vector<Column, T> 
                /// #   (\(n):vector-matrix-vector-products)
                func >< <Column, T>(matrix:Vector<Column, T>.Matrix\(n), vector:Vector\(n)<T>) 
                    -> Vector<Column, T> 
                    where Column:SIMD, Column.Scalar == T, T:\(domain)
                """
                Source.block 
                {
                    components.enumerated().map
                    { 
                        "(matrix.\($0.0) * vector.\($0.1) as Vector<Column, T>)" 
                    }.joined(separator: "\n+\n")
                }
                """
                // matrix-matrix product 
                """
                for m:Int in 2 ... 4 
                {
                    """
                    /// func (><)<T>(row:matrix:)
                    /// where T:\(domain)
                    ///     Computes the matrix product of a 1\\ ×\\ \(n) row vector, and 
                    ///     a \(n)\\ ×\\ \(m) matrix, returning a 1\\ ×\\ \(m) row vector.
                    /// 
                    ///     > note:
                    ///     This operation is less efficient than a 
                    ///     similarly-sized matrix-vector multiplication. Consider 
                    ///     rewriting linear algebra expressions that use this operation 
                    ///     in order to take full advantage of hardware acceleration.
                    /// - row   :Vector\(n)<T>.Row
                    /// - matrix:Vector\(n)<T>.Matrix\(m)
                    /// - ->    :Vector\(m)<T>.Row
                    /// #   (\(m)\(n)0:vector-matrix-matrix-\(m)-products)
                    func >< <T>(row:Vector\(n)<T>.Row, matrix:Vector\(n)<T>.Matrix\(m)) 
                        -> Vector\(m)<T>.Row
                        where T:\(domain)
                    """
                    Source.block 
                    {
                        """
                        let row:Vector\(n)<T> = row*
                        return (\((0 ..< m).map{ "row <> matrix.\($0)" }.joined(separator: ", ")))
                        """
                    }
                }
                for m:Int in 2 ... 4 
                {
                    """
                    /// func (><)<Column, T>(lhs:rhs:)
                    /// where Column:SIMD, Column.Scalar == T, T:\(domain) 
                    ///     Computes the matrix product of an *n*\\ ×\\ \(n) matrix, 
                    ///     and a \(n)\\ ×\\ \(m) matrix, returning an *n*\\ ×\\ \(m) matrix.
                    /// 
                    ///     > note:
                    ///     This operation is vectorized in the vertical direction 
                    ///     along its left-hand-operand, which means it is most efficient 
                    ///     when the `lhs` matrix has more rows than columns.
                    /// - lhs:Vector<Column, T>.Matrix\(n)
                    /// - rhs:Vector\(n)<T>.Matrix\(m)
                    /// - -> :Vector<Column, T>.Matrix\(m) 
                    /// #   (\(m)\(n)1:vector-matrix-matrix-\(m)-products)
                    func >< <Column, T>(lhs:Vector<Column, T>.Matrix\(n), rhs:Vector\(n)<T>.Matrix\(m)) 
                        -> Vector<Column, T>.Matrix\(m) 
                        where Column:SIMD, Column.Scalar == T, T:\(domain)
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
            """
            for m:Int in 2 ... 4 
            {
                """
                /// func (><)<Column, T>(diagonal:rhs:)
                /// where Column:SIMD, Column.Scalar == T, T:\(domain)
                ///     Computes the matrix product of an *n*\\ ×\\ *n* diagonal 
                ///     matrix, and an *n*\\ ×\\ \(m) matrix, returning 
                ///     an *n*\\ ×\\ \(m) matrix.
                /// 
                ///     The result of this operation is the `rhs` matrix with 
                ///     its rows scaled by the corresponding elements along the 
                ///     diagonal of `diagonal`.
                /// 
                ///     > note:
                ///     This operation is much more efficient than 
                ///     performing a full matrix multiplication.
                /// - diagonal  :Vector<Column, T>.Diagonal
                /// - rhs       :Vector<Column, T>.Matrix\(m)
                /// - ->        :Vector<Column, T>.Matrix\(m) 
                /// #   (\(m):vector-matrix-row-scaling)
                func >< <Column, T>(diagonal:Vector<Column, T>.Diagonal, rhs:Vector<Column, T>.Matrix\(m)) 
                    -> Vector<Column, T>.Matrix\(m) 
                    where Column:SIMD, Column.Scalar == T, T:\(domain)
                """
                Source.block
                {
                    "(\((0 ..< m).map{ "diagonal.diagonal * rhs.\($0)" }.joined(separator: ", ")))"
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
                /// func (><)<Column, T>(lhs:diagonal:)
                /// where Column:SIMD, Column.Scalar == T, T:\(domain)
                ///     Computes the matrix product of an *n*\\ ×\\ \(m) matrix, 
                ///     and a \(m)\\ ×\\ \(m) diagonal matrix, returning an 
                ///     *n*\\ ×\\ \(m) matrix.
                /// 
                ///     The result of this operation is the `lhs` matrix with 
                ///     its columns scaled by the corresponding elements along the 
                ///     diagonal of `diagonal`.
                /// 
                ///     > note:
                ///     This operation is much more efficient than 
                ///     performing a full matrix multiplication.
                /// - lhs       :Vector<Column, T>.Matrix\(m)
                /// - diagonal  :Vector\(m)<T>.Diagonal
                /// - ->        :Vector<Column, T>.Matrix\(m) 
                /// #   (\(m):vector-matrix-column-scaling)
                func >< <Column, T>(lhs:Vector<Column, T>.Matrix\(m), diagonal:Vector\(m)<T>.Diagonal) 
                    -> Vector<Column, T>.Matrix\(m) 
                    where Column:SIMD, Column.Scalar == T, T:\(domain)
                """
                Source.block
                {
                    """
                    (\(Self.components.cartesian.prefix(m).enumerated()
                        .map{ "lhs.\($0.0) * diagonal.diagonal.\($0.1)" }
                        .joined(separator: ", ")))
                    """
                }
            }
        }
        """
        
        // matrix operations
        extension Vector where Storage:SIMD.Transposable
        {
            /// static func Vector.diagonal(trimming:)
            /// ?   where Storage:SIMD.Transposable 
            ///     Extracts the diagonal from the given matrix.
            /// - matrix:Matrix 
            /// - ->    :Self 
            /// #   (0:vector-matrix-diagonal-usage)
            static 
            func diagonal(trimming matrix:Matrix) -> Self 
            {
                .init(storage: Storage.diagonal(trimming: matrix))
            } 
            /// static func Vector.diagonal(padding:with:)
            /// ?   where Storage:SIMD.Transposable 
            ///     Returns a matrix with the elements of the given vector along 
            ///     its diagonal, and the given fill value in all other cells.
            /// - diagonal  :Self 
            /// - fill      :T
            /// - ->        :Matrix
            /// #   (1:vector-matrix-diagonal-usage)
            static 
            func diagonal(padding diagonal:Self, with fill:T) -> Matrix 
            {
                Storage.diagonal(padding: diagonal.storage, with: fill)
            } 
        }
        extension Vector where Storage:SIMD.Transposable, T:Numeric 
        {
            /// static func Vector.diagonal(padding:)
            /// ?   where Storage:SIMD.Transposable, T:Numeric 
            ///     Returns a matrix with the elements of the given vector along 
            ///     its diagonal, and zero in all other cells.
            /// - diagonal  :Self 
            /// - ->        :Matrix
            /// #   (1:vector-matrix-diagonal-usage)
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
                /// static func Vector.trace(_:)
                /// ?   where Storage:SIMD.Transposable, T:\(domain) 
                ///     Returns the sum of the elements along the diagonal of 
                ///     the given matrix. 
                /// - matrix:Matrix 
                /// - ->    :T
                /// #   (2:vector-matrix-diagonal-usage)
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
                /// static func Vector.trace(_:)
                /// ?   where T:\(domain)
                ///     Returns the sum of the elements of the given diagonal matrix. 
                /// - diagonal  :Diagonal 
                /// - ->        :T
                /// #   (1:vector-diagonal-usage)
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
            /// static func Vector.determinant(_:) 
            /// ?   where Storage:SIMD.MatrixAlgebra 
            ///     Computes the determinant of the given matrix.
            /// - matrix:Matrix
            /// - ->    :T 
            /// #   (0:vector-matrix-inverse-usage)
            static 
            func determinant(_ matrix:Matrix) -> T 
            {
                Storage.determinant(matrix)
            }
            /// static func Vector.inverse(_:) 
            /// ?   where Storage:SIMD.MatrixAlgebra 
            ///     Computes the inverse of the given matrix.
            /// - matrix:Matrix
            ///     A matrix to compute the inverse of. 
            /// - ->    :Matrix 
            ///     The inverse of `matrix`. If `matrix` is singular 
            ///     ([`determinant(_:)`] returns zero), the result is undefined.
            /// #   (1:vector-matrix-inverse-usage)
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
            let components:ArraySlice<String> = Self.components.cartesian.prefix(n)
            """
            
            // initializers 
            extension Vector where Storage == SIMD\(n)<T>
            """
            Source.block 
            {
                Self.initializers(n: n, components: components)
            }
            """
            
            // type conversions 
            extension Vector where Storage == SIMD\(n)<T>, T:FixedWidthInteger
            """
            Source.block
            {
                """
                /// init Vector.init<U>(clamping:)
                /// where U:FixedWidthInteger 
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts an integer vector with elements of type [[`U`]] to an 
                ///     integer vector with elements of type [[`T`]], with each element 
                ///     clamped to the range of values representable by [[`T`]].
                /// - other :Vector\(n)<U> 
                /// #   (0:vector-type-conversion-usage)
                init<U>(clamping other:Vector\(n)<U>) where U:FixedWidthInteger 
                {
                    self.init(storage: .init(clamping: other.storage))
                }
                /// init Vector.init<U>(truncatingIfNeeded:)
                /// where U:FixedWidthInteger 
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts an integer vector with elements of type [[`U`]] to an 
                ///     integer vector with elements of type [[`T`]], with each element 
                ///     truncated to the bit width of [[`T`]].
                /// - other :Vector\(n)<U> 
                /// #   (1:vector-type-conversion-usage)
                init<U>(truncatingIfNeeded other:Vector\(n)<U>) where U:FixedWidthInteger 
                {
                    self.init(storage: .init(truncatingIfNeeded: other.storage))
                }
                
                /// init Vector.init<U>(_:)
                /// where U:BinaryFloatingPoint 
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts a floating point vector with elements of type [[`U`]] to an 
                ///     integer vector with elements of type [[`T`]].
                /// - other :Vector\(n)<U> 
                /// #   (2:vector-type-conversion-usage)
                init<U>(_ other:Vector\(n)<U>) 
                    where U:BinaryFloatingPoint
                {
                    self.init(storage: .init(other.storage))
                }
                /// init Vector.init<U>(_:rounding:)
                /// where U:BinaryFloatingPoint 
                /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                ///     Converts a floating point vector with elements of type [[`U`]] to an 
                ///     integer vector with elements of type [[`T`]], with each element 
                ///     rounded according to the given floating point rounding rule.
                /// - other :Vector\(n)<U> 
                /// - rule  :FloatingPointRoundingRule
                /// #   (3:vector-type-conversion-usage)
                init<U>(_ other:Vector\(n)<U>, rounding rule:FloatingPointRoundingRule) 
                    where U:BinaryFloatingPoint
                {
                    self.init(storage: .init(other.storage, rounding: rule))
                }
                
                """
                for m:Int in 2 ... 4 
                {
                    """
                    /// static func Vector.cast<U>(clamping:)
                    /// where U:FixedWidthInteger 
                    /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                    ///     Converts an integer matrix with elements of type [[`U`]] to an 
                    ///     integer matrix with elements of type [[`T`]], with each element 
                    ///     clamped to the range of values representable by [[`T`]].
                    /// - other :Vector\(n)<U>.Matrix\(m) 
                    /// - ->    :Matrix\(m) 
                    /// #   (0:vector-matrix-type-conversion-usage)
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
                    /// static func Vector.cast<U>(truncatingIfNeeded:)
                    /// where U:FixedWidthInteger 
                    /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                    ///     Converts an integer matrix with elements of type [[`U`]] to an 
                    ///     integer matrix with elements of type [[`T`]], with each element 
                    ///     truncated to the bit width of [[`T`]].
                    /// - other :Vector\(n)<U>.Matrix\(m) 
                    /// - ->    :Matrix\(m) 
                    /// #   (1:vector-matrix-type-conversion-usage)
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
                    /// static func Vector.cast<U>(_:)
                    /// where U:BinaryFloatingPoint 
                    /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                    ///     Converts a floating point matrix with elements of type [[`U`]] to an 
                    ///     integer matrix with elements of type [[`T`]].
                    /// - other :Vector\(n)<U>.Matrix\(m) 
                    /// - ->    :Matrix\(m) 
                    /// #   (2:vector-matrix-type-conversion-usage)
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
                    /// static func Vector.cast<U>(_:rounding:)
                    /// where U:BinaryFloatingPoint 
                    /// ?   where Storage == SIMD\(n)<T>, T:FixedWidthInteger
                    ///     Converts a floating point matrix with elements of type [[`U`]] to an 
                    ///     integer matrix with elements of type [[`T`]], with each element 
                    ///     rounded according to the given floating point rounding rule.
                    /// - other :Vector\(n)<U>.Matrix\(m) 
                    /// - rule  :FloatingPointRoundingRule
                    /// - ->    :Matrix\(m) 
                    /// #   (3:vector-matrix-type-conversion-usage)
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
                /// init Vector.init<U>(_:)
                /// where U:FixedWidthInteger 
                /// ?   where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
                ///     Converts an integer vector with elements of type [[`U`]] to a 
                ///     floating point vector with elements of type [[`T`]].
                /// - other :Vector\(n)<U> 
                /// #   (4:vector-type-conversion-usage)
                init<U>(_ other:Vector\(n)<U>) where U:FixedWidthInteger
                {
                    self.init(storage: .init(other.storage))
                }
                /// init Vector.init<U>(_:)
                /// where U:BinaryFloatingPoint 
                /// ?   where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
                ///     Converts a floating point vector with elements of type [[`U`]] to a 
                ///     floating point vector with elements of type [[`T`]].
                /// - other :Vector\(n)<U> 
                /// #   (5:vector-type-conversion-usage)
                init<U>(_ other:Vector\(n)<U>) where U:BinaryFloatingPoint
                {
                    self.init(storage: .init(other.storage))
                }
                
                """
                for m:Int in 2 ... 4 
                {
                    """
                    /// static func Vector.cast<U>(_:)
                    /// where U:FixedWidthInteger
                    /// ?   where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
                    ///     Converts an integer matrix with elements of type [[`U`]] to a
                    ///     floating point matrix with elements of type [[`T`]].
                    /// - other :Vector\(n)<U>.Matrix\(m) 
                    /// - ->    :Matrix\(m) 
                    /// #   (4:vector-matrix-type-conversion-usage)
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
                    /// static func Vector.cast<U>(_:)
                    /// where U:BinaryFloatingPoint
                    /// ?   where Storage == SIMD\(n)<T>, T:BinaryFloatingPoint
                    ///     Converts a floating point matrix with elements of type [[`U`]] to a
                    ///     floating point matrix with elements of type [[`T`]].
                    /// - other :Vector\(n)<U>.Matrix\(m) 
                    /// - ->    :Matrix\(m) 
                    /// #   (5:vector-matrix-type-conversion-usage)
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
                // only emit one doccomment per component, since they all have the same form 
                if n == 4 
                {
                    for (cardinal, (i, c)):(String, (Int, String)) in 
                        zip(["first", "second", "third", "fourth"], components.enumerated()) 
                    {
                        """
                        /// var Vector.\(c):T { get set }
                        """
                        for n:Int in max(1 + i, 2) ... 4 
                        {
                            """
                            /// ?   where Storage == SIMD\(n)<T>
                            """
                        }
                        """
                        ///     The \(cardinal) element of this vector.
                        /// #   (0:vector-element-access)
                        
                        """
                    }
                }
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
                    // only emit one doccomment per arity, since these all have 
                    // the same form 
                    if n == 2 
                    {
                        """
                        /// subscript Vector<Index>[_:] { get }
                        /// where Index:FixedWidthInteger & SIMDScalar 
                        """
                        for n:Int in 2 ... 4 
                        {
                            """
                            /// ?   where Storage == SIMD\(n)<T> 
                            """
                        }
                        """
                        ///     Loads the elements of this vector at the given indices 
                        ///     as a \(m)-element vector.
                        /// 
                        ///     > note:
                        ///     Unlike the [`[_:]#(arity-1)`] subscript, 
                        ///     this subscript will never trap, because all possible 
                        ///     values of its `selector` parameter are valid.
                        /// - selector  :Vector\(m)<Index>
                        ///     An integer vector specifying the index of the element 
                        ///     to load from this vector, for each element of the result.
                        /// 
                        ///     It is acceptable for the index vector to specify 
                        ///     out-of-range indices, in which case, the indices 
                        ///     are interpreted modulo *n*, where *n* is the 
                        ///     number of elements in this vector. 
                        /// - ->        :Vector\(m)<T>
                        /// #   (2:vector-swizzle-usage)
                        /// #   (arity-\(m))
                        
                        /// subscript Vector<Index>[_:] { get }
                        /// where Index:FixedWidthInteger & SIMDScalar 
                        """
                        for n:Int in 2 ... 4 
                        {
                            """
                            /// ?   where Storage == SIMD\(n)<T> 
                            """
                        }
                        """
                        ///     Loads the specified vector swizzle from this vector.
                        /// 
                        ///     This subscript is shorthand for passing the 
                        ///     [`(VectorSwizzle\(m)).selector`] value of `swizzle`
                        ///     to the [`[_:]#(arity-\(m))`] subscript.
                        ///     
                        ///     > note:
                        ///     This subscript will never trap, even if 
                        ///     the specified vector swizzle references elements 
                        ///     not present in [[`Self`]].
                        /// - swizzle   :VectorSwizzle\(m)
                        ///     The vector swizzle to extract.
                        /// 
                        ///     It is acceptable for the vector swizzle to specify 
                        ///     elements that are not present in [[`Self`]], in 
                        ///     which case, this vector instance is interpreted 
                        ///     as an infinite-length vector with the missing elements 
                        ///     filled in by cycling through the existing elements. 
                        /// 
                        ///     For example, if [[`Self`]] is [[`Vector3<T>`]], 
                        ///     then the swizzle 
                        ///     [`(VectorSwizzle\(m)).\(String.init(repeating: "w", count: m))`]
                        ///     refers to the same elements as 
                        ///     [`(VectorSwizzle\(m)).\(String.init(repeating: "x", count: m))`].
                        /// - ->        :Vector\(m)<T>
                        /// #   (1:vector-swizzle-usage)
                        """
                    }
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
        }
        """
        
        // swizzle constants 
        """
        for n:Int in 2 ... 4 
        {
            """
            /// struct VectorSwizzle\(n)
            /// :   Hashable 
            ///     A type providing \(n)-element vector swizzle constants.
            /// #   (0:vector-swizzle-usage)
            /// #   (10:math-types)
            struct VectorSwizzle\(n):Hashable 
            """
            Source.block 
            {
                """
                /// var VectorSwizzle\(n).selector:Vector\(n)<UInt8> 
                ///     The index vector containing the indices specified by 
                ///     this vector swizzle.
                var selector:Vector\(n)<UInt8>
                """
                
                for permutation:[Int] in Self.permutations(4, k: n)
                {
                    let name:String     = permutation.map{ Self.components.cartesian[$0] }.joined()
                    let indices:String  = permutation.map(String.init(_:)).joined(separator: ", ")
                    """
                    /// static let VectorSwizzle\(n).\(name):Self 
                    /// #   (0:)
                    static let \(name):Self = .init(selector: (\(indices))*)
                    """
                }
            }
        }
    }
}
