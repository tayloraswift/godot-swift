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
    static 
    var swift:String 
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
        
        """
        infix   operator <>  : MultiplicationPrecedence // dot/inner product
        infix   operator >|< : MultiplicationPrecedence // cross product
        infix   operator ><  : MultiplicationPrecedence // matrix product
        
        postfix operator *                              // matrix transpose
        
        infix   operator ~<  : ComparisonPrecedence     // vector is inside sphere, exclusive
        infix   operator ~~  : ComparisonPrecedence     // vector is inside sphere, inclusive
        infix   operator !~  : ComparisonPrecedence     // vector is outside sphere, inclusive
        infix   operator !>  : ComparisonPrecedence     // vector is outside sphere, exclusive
        """
        for n:Int in 2 ... 4 
        {
            let components:ArraySlice<String> = components.cartesian.prefix(n)
            """
            
            struct Vector\(n)<T>:Hashable where T:SIMDScalar 
            """
            Source.block 
            {
                """
                struct Mask:Hashable 
                {
                    var storage:SIMDMask<SIMD\(n)<T.SIMDMaskScalar>>
                }
                
                var storage:SIMD\(n)<T>
                
                // initializers 
                init(storage:SIMD\(n)<T>) 
                {
                    self.storage = storage
                }
                init(repeating value:T) 
                {
                    self.storage = .init(repeating: value)
                }
                """
                Self.initializers(n: n, components: components)
            }
            """
            // constants 
            extension Vector\(n) where T:FixedWidthInteger
            """
            Source.block
            {
                """
                static 
                var zero:Self   { .init(storage: .zero) }
                static 
                var one:Self    { .init(storage:  .one) }
                """
            }
            """
            extension Vector\(n) where T:BinaryFloatingPoint
            """
            Source.block
            {
                """
                static 
                var zero:Self   { .init(storage: .zero) }
                static 
                var one:Self    { .init(storage:  .one) }
                """
            }
            """
            // type conversions 
            extension Vector\(n) where T:FixedWidthInteger
            """
            Source.block
            {
                """
                init<U>(clamping other:Vector\(n)<U>) where U:FixedWidthInteger 
                {
                    self.storage = .init(clamping: other.storage)
                }
                init<U>(truncatingIfNeeded other:Vector\(n)<U>) where U:FixedWidthInteger 
                {
                    self.storage = .init(truncatingIfNeeded: other.storage)
                }
                
                init<U>(_ other:Vector\(n)<U>) 
                    where U:BinaryFloatingPoint
                {
                    self.storage = .init(other.storage)
                }
                init<U>(_ other:Vector\(n)<U>, rounding rule:FloatingPointRoundingRule) 
                    where U:BinaryFloatingPoint
                {
                    self.storage = .init(other.storage, rounding: rule)
                }
                """
            }
            """
            extension Vector\(n) where T:BinaryFloatingPoint
            """
            Source.block
            {
                """
                init<U>(_ other:Vector\(n)<U>) where U:FixedWidthInteger
                {
                    self.storage = .init(other.storage)
                }
                init<U>(_ other:Vector\(n)<U>) where U:BinaryFloatingPoint
                {
                    self.storage = .init(other.storage)
                }
                """
            }
            """
            // components and swizzle-subscripts
            extension Vector\(n)
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
                
                """
                for m:Int in 2 ... 4 
                {
                    """
                    subscript<Index>(selection:Vector\(m)<Index>) -> Vector\(m)<T>
                        where Index:FixedWidthInteger & SIMDScalar 
                    {
                        get 
                        {
                            .init(storage: self.storage[selection.storage])
                        }
                    }
                    subscript(selection:VectorSwizzle\(m)) -> Vector\(m)<T>
                    {
                        get 
                        {
                            .init(storage: self.storage[selection.storage])
                        }
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
                "var storage:SIMD\(n)<UInt8>"
                
                for permutation:[Int] in Self.permutations(n)
                {
                    let name:String     = permutation.map{ components[$0] }.joined()
                    let indices:String  = permutation.map(String.init(_:)).joined(separator: ", ")
                    "static let \(name):Self = .init(storage: .init(\(indices)))"
                }
            }
            """
            // horizontal operations 
            extension Vector\(n) where T:FixedWidthInteger
            """
            Source.block 
            {
                """
                // note: uses wrapping addition
                var sum:T 
                {
                    self.storage.wrappedSum()
                }
                """
            }
            """
            extension Vector\(n) where T:BinaryFloatingPoint
            """
            Source.block 
            {
                """
                var sum:T 
                {
                    self.storage.sum()
                }
                """
            }
            """
            extension Vector\(n) where T:Comparable
            """
            Source.block 
            {
                """
                var min:T 
                {
                    self.storage.min()
                }
                var max:T 
                {
                    self.storage.max()
                }
                """
            }
            """
            extension Vector\(n) 
            """
            Source.block 
            {
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
            // element-wise operations
            extension Vector\(n) where T:FixedWidthInteger
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
            extension Vector\(n) where T:BinaryFloatingPoint
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
                func addingProduct(_ a:Self, b:Self) -> Self 
                {
                    .init(storage: self.storage.addingProduct(a.storage, b.storage))
                }
                func addingProduct(_ a:Self, b:T) -> Self 
                {
                    .init(storage: self.storage.addingProduct(a.storage, b))
                }
                func addingProduct(_ a:T, b:Self) -> Self 
                {
                    .init(storage: self.storage.addingProduct(a, b.storage))
                }
                mutating 
                func addProduct(_ a:Self, b:Self) 
                {
                    self.storage.addProduct(a.storage, b.storage)
                }
                mutating 
                func addProduct(_ a:Self, b:T) 
                {
                    self.storage.addProduct(a.storage, b)
                }
                mutating 
                func addProduct(_ a:T, b:Self) 
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
                """
            }
            """
            // comparable-related functionality
            extension Vector\(n) where T:Comparable 
            """
            Source.block 
            {
                """
                struct Rectangle 
                {
                    var lowerBound:Vector\(n)<T>
                    var upperBound:Vector\(n)<T>
                }
                
                static 
                func ... (lhs:Self, rhs:Self) -> Rectangle
                {
                    .init(lowerBound: lhs, upperBound: rhs)
                }
                
                func clamped(to rectangle:Rectangle) -> Self 
                {
                    .init(storage: self.storage.clamped(
                        lowerBound: rectangle.lowerBound.storage,
                        upperBound: rectangle.upperBound.storage))
                }
                mutating 
                func clamp(to rectangle:Rectangle) 
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
            }
            """
            extension Vector\(n) where T:SignedInteger & FixedWidthInteger & Comparable
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
                    // saturating twos complement negation
                    .max(self, 0 - self)
                }
            }
            extension Vector\(n) where T:BinaryFloatingPoint & Comparable
            {
                static 
                func abs(_ self:Self) -> Self 
                {
                    .max(self, -self)
                }
            }
            
            // geometric operations 
            """
            for domain:String in ["FixedWidthInteger", "BinaryFloatingPoint"]
            {
                """
                extension Vector\(n) where T:\(domain) 
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
                        if n == 2 
                        {
                            """
                            // cross product 
                            static 
                            func >|< (lhs:Self, rhs:Self) -> T
                            {
                                lhs.x * rhs.y - rhs.x * lhs.y
                            }
                            """
                        }
                        if n == 3 
                        {
                            """
                            // cross product 
                            static 
                            func >|< (lhs:Self, rhs:Self) -> Self
                            {
                                lhs[.yzx] * rhs[.zxy] 
                                - 
                                rhs[.yzx] * lhs[.zxy]
                            }
                            """
                        }
                        
                        """
                        var norm:T 
                        {
                            self <> self 
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
            extension Vector\(n) 
            """
            Source.block 
            {
                """
                typealias Diagonal  = (diagonal:Self, container:Void)
                
                typealias Row       = (vector:Self, container:Void)
                """
                for m:Int in 2 ... 4 
                {
                """
                typealias Matrix\(m)   = (\(repeatElement("Self", count: m).joined(separator: ", ")))
                """
                }
            }
            """
            postfix 
            func * <T>(column:Vector\(n)<T>) -> Vector\(n)<T>.Row
                where T:SIMDScalar
            {
                (column, ())
            }
            postfix 
            func * <T>(row:Vector\(n)<T>.Row) -> Vector\(n)<T>
                where T:SIMDScalar
            {
                row.vector
            }
            """
            for m:Int in 2 ... 4 
            {
                """
                postfix 
                func * <T>(matrix:Vector\(n)<T>.Matrix\(m)) -> Vector\(m)<T>.Matrix\(n)
                    where T:SIMDScalar
                """
                Source.block 
                {
                    Source.block(delimiters: ("(", ")"))
                    {
                        components.map 
                        {
                            (c:String) in 
                            "Vector\(m)<T>.init(\((0 ..< m).map{ "matrix.\($0).\(c)" }.joined(separator: ", ")))"
                        }.joined(separator: ",\n")
                    }
                }
            }
            
            for domain:String in ["FixedWidthInteger", "BinaryFloatingPoint"]
            {
                """
                extension Vector\(n) where T:\(domain)
                """
                Source.block 
                {
                    """
                    static 
                    func diagonal(_ diagonal:Self) -> Diagonal  
                    {
                        (diagonal, ())
                    }
                    static 
                    func diagonal(_ diagonal:Diagonal) -> Self  
                    {
                        diagonal.diagonal
                    }
                    
                    static 
                    func trace(_ matrix:Matrix\(n)) -> T 
                    {
                        \(components.enumerated().map{ "matrix.\($0.0).\($0.1)" }.joined(separator: " + "))
                    }
                    
                    // vector outer product
                    """
                    for m:Int in 2 ... 4 
                    {
                        """
                        static 
                        func >< (column:Self, row:Vector\(m)<T>.Row) -> Vector\(m)<T>.Matrix\(n) 
                        """
                        Source.block 
                        {
                            Source.block(delimiters: ("(", ")"))
                            {
                                components
                                    .map{ (c:String) in "column.\(c) * row.vector" }
                                    .joined(separator: ",\n")
                            }
                        }
                    }
                    "// matrix-vector product"
                    for m:Int in 2 ... 4 
                    {
                        """
                        static 
                        func >< (matrix:Matrix\(m), vector:Self) -> Vector\(m)<T> 
                        {
                            (vector* >< matrix*).vector
                        }
                        """
                    }
                }
                "// vector-matrix product"
                for m:Int in 2 ... 4 
                {
                    """
                    func >< <T>(row:Vector\(n)<T>.Row, matrix:Vector\(m)<T>.Matrix\(n)) 
                        -> Vector\(m)<T>.Row 
                        where T:SIMDScalar & \(domain)
                    """
                    Source.block
                    {
                        for (i, component):(Int, String) in components.enumerated() 
                        {
                            "let \(component):Vector\(m)<T> = matrix.\(i) * row.vector.\(component)"
                        }
                        "return (\(components.joined(separator: " + ")), ())"
                    }
                }
                "// matrix-matrix product"
                for m:Int in 2 ... 4 
                {
                    """
                    func >< <T>(lhs:Vector\(n)<T>.Matrix\(m), rhs:Vector\(m)<T>.Matrix\(n)) 
                        -> Vector\(m)<T>.Matrix\(m) 
                        where T:SIMDScalar & \(domain)
                    """
                    Source.block
                    {
                        Source.block(delimiters: ("(", ")"))
                        {
                            (0 ..< m).map{ "(lhs.\($0)* >< rhs).vector" }.joined(separator: ",\n")
                        }
                    }
                }
                "// row scaling"
                for m:Int in 2 ... 4 
                {
                    """
                    func >< <T>(lhs:Vector\(n)<T>.Diagonal, rhs:Vector\(m)<T>.Matrix\(n)) 
                        -> Vector\(m)<T>.Matrix\(n) 
                        where T:SIMDScalar & \(domain)
                    """
                    Source.block
                    {
                        Source.block(delimiters: ("(", ")"))
                        {
                            components.enumerated()
                                .map{ "lhs.diagonal.\($0.1) * rhs.\($0.0)" }
                                .joined(separator: ",\n")
                        }
                    }
                }
                "// column scaling"
                for m:Int in 2 ... 4 
                {
                    """
                    func >< <T>(lhs:Vector\(n)<T>.Matrix\(m), rhs:Vector\(n)<T>.Diagonal) 
                        -> Vector\(n)<T>.Matrix\(m) 
                        where T:SIMDScalar & \(domain)
                    """
                    Source.block
                    {
                        Source.block(delimiters: ("(", ")"))
                        {
                            (0 ..< m).map{ "lhs.\($0) * rhs.diagonal" }
                                .joined(separator: ",\n")
                        }
                    }
                }
            }
        }
    }
}
