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
        
        infix   operator <>  : MultiplicationPrecedence // dot/inner product
        infix   operator >|< : MultiplicationPrecedence // cross product
        infix   operator ><  : MultiplicationPrecedence // matrix product
        
        postfix operator *                              // matrix transpose
        
        infix   operator ~<  : ComparisonPrecedence     // vector is inside sphere, exclusive
        infix   operator ~~  : ComparisonPrecedence     // vector is inside sphere, inclusive
        infix   operator !~  : ComparisonPrecedence     // vector is outside sphere, inclusive
        infix   operator !>  : ComparisonPrecedence     // vector is outside sphere, exclusive
        
        // we must parameterize the `Storage<T>` and `T` types separately, or 
        // else we cannot specialize on `Storage<_>` while keeping `T` generic.
        struct Vector<Storage, T>:Hashable 
            where Storage:SIMD, T:SIMDScalar, T == Storage.Scalar
        {
            struct Mask
            {
                var storage:SIMDMask<Storage.MaskStorage>
            }
            
            var storage:Storage 
            
            init(storage:Storage)
            {
                self.storage = storage
            }
        }
        
        // initializations 
        extension Vector 
        {
            init(repeating value:T) 
            {
                self.init(storage: .init(repeating: value))
            }
            init(to value:T, where mask:Mask) 
            {
                self.init(storage: .init(repeating: value).replacing(with: value, where: mask.storage))
            }
        }
        // assignments
        extension Vector 
        {
            mutating 
            func replace(with scalar:T, where mask:Mask) 
            {
                self.storage.replace(with: scalar, where: mask.storage)
            }
            mutating 
            func replace(with other:Self, where mask:Mask) 
            {
                self.storage.replace(with: other.storage, where: mask.storage)
            }
            
            func replacing(with scalar:T, where mask:Mask) -> Self
            {
                .init(storage: self.storage.replacing(with: scalar, where: mask.storage))
            }
            func replacing(with other:Self, where mask:Mask) -> Self
            {
                .init(storage: self.storage.replacing(with: other.storage, where: mask.storage))
            }
        }
        
        // `Comparable`-related functionality
        protocol VectorRangeExpression
        {
            associatedtype Storage  where Storage:SIMD 
            associatedtype T        where T:SIMDScalar, T == Storage.Scalar 
            
            typealias Bound = Vector<Storage, T>
            
            func contains(_ element:Bound) -> Bool 
        }
        extension VectorRangeExpression 
        {
            static 
            func ~= (pattern:Self, element:Bound) -> Bool 
            {
                pattern.contains(element)
            }
        }
        
        protocol VectorFiniteRangeExpression:VectorRangeExpression 
        {
            init(lowerBound:Bound, upperBound:Bound)
            var lowerBound:Bound 
            {
                get 
            }
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
            struct Rectangle:VectorFiniteRangeExpression, Hashable
            {
                var lowerBound:Vector<Storage, T>
                var upperBound:Vector<Storage, T>
                
                func contains(_ element:Vector<Storage, T>) -> Bool 
                {
                    Vector<Storage, T>.all(
                        (self.lowerBound <= element) & (element < self.upperBound))
                }
            }
            
            struct ClosedRectangle:VectorFiniteRangeExpression, Hashable
            {
                var lowerBound:Vector<Storage, T>
                var upperBound:Vector<Storage, T>
                
                func contains(_ element:Vector<Storage, T>) -> Bool 
                {
                    Vector<Storage, T>.all(
                        (self.lowerBound <= element) & (element <= self.upperBound))
                }
            }
            
            static 
            func ..< (lhs:Self, rhs:Self) -> Rectangle
            {
                .init(lowerBound: lhs, upperBound: rhs)
            }
            static 
            func ... (lhs:Self, rhs:Self) -> ClosedRectangle
            {
                .init(lowerBound: lhs, upperBound: rhs)
            }
            
            func clamped(to rectangle:ClosedRectangle) -> Self 
            {
                .init(storage: self.storage.clamped(
                    lowerBound: rectangle.lowerBound.storage,
                    upperBound: rectangle.upperBound.storage))
            }
            mutating 
            func clamp(to rectangle:ClosedRectangle) 
            {
                self.storage.clamp(
                    lowerBound: rectangle.lowerBound.storage,
                    upperBound: rectangle.upperBound.storage)
            } 
            """
            for comparator:String in ["<", "<=", "!=", "==", ">=", ">"] 
            {
                """
                static 
                func \(comparator) (lhs:Self, rhs:Self) -> Mask 
                {
                    .init(storage: lhs.storage .\(comparator) rhs.storage)
                }
                static 
                func \(comparator) (lhs:Self, rhs:T) -> Mask 
                {
                    .init(storage: lhs.storage .\(comparator) rhs)
                }
                static 
                func \(comparator) (lhs:T, rhs:Self) -> Mask 
                {
                    .init(storage: lhs .\(comparator) rhs.storage)
                }
                """
            }
            for (vended, base):(String, String) in 
            [
                ("min", "pointwiseMin"), ("max", "pointwiseMax")
            ] 
            {
                """
                static 
                func \(vended)(_ a:Self, _ b:Self) -> Self
                {
                    .init(storage: \(base)(a.storage, b.storage))
                }
                """
            }
            for (vended, base):(String, String) in [("min", "min"), ("max", "max")] 
            {
                """
                var \(vended):T 
                {
                    self.storage.\(base)()
                }
                """
            }
            """
            static 
            func any(_ mask:Mask) -> Bool 
            {
                Swift.any(mask.storage)
            }
            static 
            func all(_ mask:Mask) -> Bool 
            {
                Swift.all(mask.storage)
            }
            """
        }
        """
        extension Vector where T:SignedInteger & FixedWidthInteger 
        {
            // note: T.min maps to T.max 
            static 
            func abs(clamping self:Self) -> Self 
            {
                // saturating twos complement negation
                .max(~self, .abs(wrapping: self))
            }
            // note: T.min remains T.min 
            static 
            func abs(wrapping self:Self) -> Self 
            {
                .max(self, 0 - self)
            }
        }
        extension Vector where T:BinaryFloatingPoint 
        {
            static 
            func abs(_ self:Self) -> Self 
            {
                .max(self, -self)
            }
        }
        extension Vector.Mask 
        """
        Source.block 
        {
            let operators:[(String, String)] = 
            [
                ("|", ".|"),
                ("&", ".&"),
                ("^", ".^"),
            ]
            for (vended, base):(String, String) in operators
            {
                """
                static 
                func \(vended) (lhs:Self, rhs:Self) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs.storage)
                }
                static 
                func \(vended) (lhs:Self, rhs:Bool) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs)
                }
                static 
                func \(vended) (lhs:Bool, rhs:Self) -> Self 
                {
                    .init(storage: lhs \(base) rhs.storage)
                }
                """
            }
            // miscellaneous 
            """
            static prefix 
            func ~ (self:Self) -> Self
            {
                .init(storage: .!self.storage)
            }
            """
            for (vended, base):(String, String) in operators
            {
                """
                static 
                func \(vended)= (lhs:inout Self, rhs:Self)  
                {
                    lhs.storage \(base)= rhs.storage
                }
                static 
                func \(vended)= (lhs:inout Self, rhs:Bool)  
                {
                    lhs.storage \(base)= rhs
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
                static 
                var zero:Self   { .init(storage: .zero) }
                static 
                var one:Self    { .init(storage:  .one) }
            }
            extension Vector.Diagonal where T:\(domain)
            {
                static 
                var zero:Self       { Vector<Storage, T>.diagonal(.zero) }
                static 
                var identity:Self   { Vector<Storage, T>.diagonal(.one)  }
            }
            """
        }
        """
        
        // horizontal operations 
        extension Vector where T:FixedWidthInteger
        {
            // note: uses wrapping addition
            var sum:T 
            {
                self.storage.wrappedSum()
            }
        }
        extension Vector where T:BinaryFloatingPoint
        {
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
            let operators:[(vended:String, base:String)] =
            [
                ("|", "|"),
                ("&", "&"),
                ("^", "^"),
                
                ("&<<", "&<<"),
                ("&>>", "&>>"),
                
                ("+", "&+"),
                ("-", "&-"),
                ("*", "&*"),
                ("/", "/"),
                ("%", "%"),
            ]
            for (vended, base):(String, String) in operators
            {
                """
                static 
                func \(vended) (lhs:Self, rhs:Self) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs.storage)
                }
                static 
                func \(vended) (lhs:Self, rhs:T) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs)
                }
                static 
                func \(vended) (lhs:T, rhs:Self) -> Self 
                {
                    .init(storage: lhs \(base) rhs.storage)
                }
                """
            }
            for (vended, base):(String, String) in operators
            {
                """
                static 
                func \(vended)= (lhs:inout Self, rhs:Self)  
                {
                    lhs.storage \(base)= rhs.storage
                }
                static 
                func \(vended)= (lhs:inout Self, rhs:T)  
                {
                    lhs.storage \(base)= rhs
                }
                """
            }
            // miscellaneous 
            """
            static prefix
            func ~ (self:Self) -> Self 
            {
                .init(storage: ~self.storage)
            }
            
            var leadingZeroBitCount:Self 
            {
                .init(storage: self.storage.leadingZeroBitCount)
            }
            var nonzeroBitCount:Self 
            {
                .init(storage: self.storage.nonzeroBitCount)
            }
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
            let operators:[(vended:String, base:String)] =
            [
                ("+", "+"),
                ("-", "-"),
                ("*", "*"),
                ("/", "/")
            ]
            for (vended, base):(String, String) in operators
            {
                """
                static 
                func \(vended) (lhs:Self, rhs:Self) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs.storage)
                }
                static 
                func \(vended) (lhs:Self, rhs:T) -> Self 
                {
                    .init(storage: lhs.storage \(base) rhs)
                }
                static 
                func \(vended) (lhs:T, rhs:Self) -> Self 
                {
                    .init(storage: lhs \(base) rhs.storage)
                }
                """
            }
            for (vended, base):(String, String) in operators
            {
                """
                static 
                func \(vended)= (lhs:inout Self, rhs:Self)  
                {
                    lhs.storage \(base)= rhs.storage
                }
                static 
                func \(vended)= (lhs:inout Self, rhs:T)  
                {
                    lhs.storage \(base)= rhs
                }
                """
            }
            // miscellaneous
            """
            static prefix
            func - (self:Self) -> Self 
            {
                .init(storage: -self.storage)
            }
            func addingProduct(_ a:Self, _ b:Self) -> Self 
            {
                .init(storage: self.storage.addingProduct(a.storage, b.storage))
            }
            func addingProduct(_ a:Self, _ b:T) -> Self 
            {
                .init(storage: self.storage.addingProduct(a.storage, b))
            }
            func addingProduct(_ a:T, _ b:Self) -> Self 
            {
                .init(storage: self.storage.addingProduct(a, b.storage))
            }
            mutating 
            func addProduct(_ a:Self, _ b:Self) 
            {
                self.storage.addProduct(a.storage, b.storage)
            }
            mutating 
            func addProduct(_ a:Self, _ b:T) 
            {
                self.storage.addProduct(a.storage, b)
            }
            mutating 
            func addProduct(_ a:T, _ b:Self) 
            {
                self.storage.addProduct(a, b.storage)
            }
            func rounded(_ rule:FloatingPointRoundingRule = .toNearestOrAwayFromZero) -> Self 
            {
                .init(storage: self.storage.rounded(rule))
            }
            mutating 
            func round(_ rule:FloatingPointRoundingRule = .toNearestOrAwayFromZero) 
            {
                self.storage.round(rule)
            }
            
            static 
            func sqrt(_ self:Self) -> Self 
            {
                .init(storage: self.storage.squareRoot())
            }
            
            static 
            func interpolate(_ a:Self, _ b:Self, by t:T) 
                -> Self
            {
                (a * (1 - t)).addingProduct(b, t)
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
                static 
                func \(function)(_ self:Self) -> Self 
                {
                    self.map(T.\(function)(_:))
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
                // dot product 
                static 
                func <> (lhs:Self, rhs:Self) -> T 
                {
                    (lhs * rhs).sum
                }
                """
                if domain == "BinaryFloatingPoint" 
                {
                    """
                    
                    var norm:T 
                    {
                        (self <> self).squareRoot() 
                    }
                    func normalized() -> Self
                    {
                        self / self.norm 
                    }
                    mutating 
                    func normalize() 
                    {
                        self /= self.norm 
                    }
                    
                    static 
                    func ~< (self:Self, radius:T) -> Bool 
                    {
                        self <> self <  radius * radius 
                    }
                    static 
                    func ~~ (self:Self, radius:T) -> Bool 
                    {
                        self <> self <= radius * radius 
                    }
                    static 
                    func !~ (self:Self, radius:T) -> Bool 
                    {
                        self <> self >= radius * radius 
                    }
                    static 
                    func !> (self:Self, radius:T) -> Bool 
                    {
                        self <> self  > radius * radius 
                    }
                    """
                }
            }
        }
        """
        // cross product 
        extension Vector where Storage == SIMD2<T>, T:BinaryFloatingPoint 
        {
            static 
            func >|< (lhs:Self, rhs:Self) -> T
            {
                lhs.x * rhs.y - rhs.x * lhs.y
            }
        }
        extension Vector where Storage == SIMD3<T>, T:BinaryFloatingPoint 
        {
            static 
            func >|< (lhs:Self, rhs:Self) -> Self
            {
                lhs[.yzx] * rhs[.zxy] 
                - 
                rhs[.yzx] * lhs[.zxy]
            }
        }
        
        // linear aggregates
        protocol _SIMDTransposable:SIMD 
        {
            associatedtype Transpose
            associatedtype Square 
            
            func map(_ transform:(Scalar) -> Scalar) -> Self 
            
            static 
            func diagonal(trimming matrix:Square) -> Self 
            static 
            func diagonal(padding diagonal:Self, with fill:Scalar) -> Square 
        }
        protocol _SIMDMatrixAlgebra:SIMD.Transposable 
        {
            static 
            func determinant(_ matrix:Square) -> Scalar 
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
            extension SIMD\(n):SIMD.Transposable 
            """
            Source.block 
            {
                """
                typealias Transpose = (\(repeatElement("Scalar", count: n).joined(separator: ", ")))
                typealias Square    = 
                """
                Source.block(delimiters: ("(", ")"))
                {
                    repeatElement("Vector<Self, Scalar>", count: n).joined(separator: ",\n")
                }
                """
                
                func map(_ transform:(Scalar) -> Scalar) -> Self 
                {
                    .init(\(components.cartesian.prefix(n)
                        .map{ "transform(self.\($0))" }
                        .joined(separator: ", ")))
                }
                
                static 
                func diagonal(trimming matrix:Square) -> Self 
                {
                    .init(\(components.cartesian.prefix(n).enumerated()
                        .map{ "matrix.\($0.0).\($0.1)" }
                        .joined(separator: ", ")))
                }
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
        extension SIMD2:SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
        {
            static 
            func determinant(_ A:Square) -> Scalar 
            {
                A.0 >|< A.1
            }
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
        extension SIMD3:SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
        {
            static 
            func determinant(_ A:Square) -> Scalar 
            {
                A.0 >|< A.1 <> A.2
            }
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
                
                /*
                let a:Vector<Self, Scalar> = .init(
                    A.1.y * A.2.z - A.2.y * A.1.z,
                    A.2.y * A.0.z - A.0.y * A.2.z,
                    A.0.y * A.1.z - A.1.y * A.0.z)
                let b:Vector<Self, Scalar> = .init(
                    A.1.z * A.2.x - A.2.z * A.1.x,
                    A.2.z * A.0.x - A.0.z * A.2.x,
                    A.0.z * A.1.x - A.1.z * A.0.x)
                let c:Vector<Self, Scalar> = .init(
                    A.1.x * A.2.y - A.2.x * A.1.y,
                    A.2.x * A.0.y - A.0.x * A.2.y,
                    A.0.x * A.1.y - A.1.x * A.0.y)
                
                let a:Vector<Self, Scalar> = .init(
                    A.1.y * A.2.z - A.2.y * A.1.z,
                    A.2.y * A.0.z - A.0.y * A.2.z,
                    A.0.y * A.1.z - A.1.y * A.0.z)
                let b:Vector<Self, Scalar> = .init(
                    A.2.x * A.1.z - A.1.x * A.2.z,
                    A.0.x * A.2.z - A.2.x * A.0.z,
                    A.1.x * A.0.z - A.0.x * A.1.z)
                let c:Vector<Self, Scalar> = .init(
                    A.1.x * A.2.y - A.2.x * A.1.y,
                    A.2.x * A.0.y - A.0.x * A.2.y,
                    A.0.x * A.1.y - A.1.x * A.0.y)
                */
            }
        }
        """
        
        """
        extension Vector where Storage:SIMD.Transposable
        {
            typealias Row       = Storage.Transpose 
            typealias Matrix    = Storage.Square
            
            func map(_ transform:(T) -> T) -> Self 
            {
                .init(storage: self.storage.map(transform))
            }
        }
        extension Vector 
        """
        Source.block 
        {
            for m:Int in 2 ... 4 
            {
                """
                typealias Matrix\(m) = (\(repeatElement("Self", count: m).joined(separator: ", ")))
                """
            }
            
            """
            
            struct Diagonal:Hashable 
            {
                fileprivate 
                var diagonal:Vector<Storage, T> 
            }
            
            static 
            func diagonal(_ diagonal:Self) -> Diagonal  
            {
                .init(diagonal: diagonal)
            }
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
                .init(\((0 ..< n).map{ "row.\($0)" }.joined(separator: ", ")))
            } 
            
            postfix 
            func * <T>(column:Vector\(n)<T>) -> Vector\(n)<T>.Row
                where T:SIMDScalar
            {
                (\(components.map{ "column.\($0)" }.joined(separator: ", ")))
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
        Source.section(name: "vector.part.swift")
        {
            Self.code
        }
    }
}
