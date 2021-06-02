enum SIMDProtocols 
{
    @Source.Code 
    static 
    var swift:String 
    {
        """
        /// extension SIMD 
        extension SIMD 
        {
            typealias Extendable    = _SIMDExtendable 
            typealias Transposable  = _SIMDTransposable 
            typealias MatrixAlgebra = _SIMDMatrixAlgebra 
        }
        /// protocol SIMD.Extendable 
        /// :   SIMD 
        ///     An SIMD backing storage type from which a different 
        ///     SIMD backing storage type can be created by appending an additional 
        ///     scalar element.
        protocol _SIMDExtendable:SIMD 
        {
            /// associatedtype SIMD.Extendable.Extended 
            /// where Extended:SIMD, Extended.Scalar == Scalar
            associatedtype Extended where Extended:SIMD, Extended.Scalar == Scalar
            
            /// func SIMD.Extendable.extended(with:)
            /// required 
            ///     Concatenates this storage value and the given scalar, 
            ///     returning an extended storage value.
            /// - scalar:Scalar 
            /// - ->    :Extended
            func extended(with scalar:Scalar) -> Extended
            
            /// static func SIMD.Extendable.weights(of:)
            /// required 
            ///     Extracts an instance of [`Self`] from the given extended storage 
            ///     value by discarding the last scalar element. 
            /// - extended  :Extended 
            /// - ->        :Self 
            static 
            func weights(of extended:Extended) -> Self 
            /// static func SIMD.Extendable.bias(of:)
            /// required 
            ///     Extracts the last scalar element in the given extended storage 
            ///     value. 
            /// - extended  :Extended 
            /// - ->        :Scalar 
            static 
            func bias(of extended:Extended) -> Scalar 
        }
        /// protocol SIMD.Transposable
        /// :   SIMD 
        ///     An SIMD backing storage type which has a transposed representation.
        /// 
        ///     You can conform additional types to this protocol to add linear algebra 
        ///     support for 8-, 16-, etc. dimensional vectors. Only do this if you really 
        ///     know what you are doing.
        /// #   (1:math-protocols)
        protocol _SIMDTransposable:SIMD 
        {
            /// associatedtype SIMD.Transposable.Transpose 
            ///     A type representing the transposed form of this vector storage 
            ///     type. 
            /// 
            ///     > note:
            ///     When conforming additional types to [`Transposable`], 
            ///     we recommend setting this `associatedtype` to a tuple type with 
            ///     *n* elements of type [`(SIMD).Scalar`].
            associatedtype Transpose
            
            /// associatedtype SIMD.Transposable.Square 
            ///     A square matrix type which a type conforming to [`Transposable`] 
            ///     supports extracting the diagonal of. 
            associatedtype Square 
            
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
        /// #   (2:math-protocols)
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
        """
        for n:Int in 2 ... 3 
        {
            """
            /// extension SIMD\(n)
            /// :   SIMD.Extendable 
            extension SIMD\(n):SIMD.Extendable 
            """
            Source.block 
            {
                """
                /// typealias SIMD\(n).Extended = SIMD\(n + 1)<Scalar> 
                /// ?:  SIMD.Extendable
                typealias Extended = SIMD\(n + 1)<Scalar>
                
                /// func SIMD\(n).extended(with:)
                /// ?:  SIMD.Extendable
                /// - scalar:Scalar 
                /// - ->    :SIMD\(n + 1)<Scalar>
                func extended(with scalar:Scalar) -> SIMD\(n + 1)<Scalar>
                {
                    .init(self, scalar)
                }
                
                /// static func SIMD\(n).weights(of:)
                /// ?:  SIMD.Extendable
                /// - extended  :SIMD\(n + 1)<Scalar>
                /// - ->        :Self 
                static 
                func weights(of extended:SIMD\(n + 1)<Scalar>) -> Self 
                {
                    extended[SIMD\(n)<UInt8>.init(\((0 ..< n).map(String.init(_:)).joined(separator: ", ")))]
                }
                /// static func SIMD\(n).bias(of:)
                /// ?:  SIMD.Extendable
                /// - extended  :SIMD\(n + 1)<Scalar>
                /// - ->        :Scalar 
                static 
                func bias(of extended:Extended) -> Scalar 
                {
                    extended.\(Vector.components.cartesian[n])
                }
                """
            }
        }
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
                /// ?:  SIMD.Transposable 
                /// - column:Self
                /// - ->    :Transpose
                static 
                func transpose(_ column:Self) -> Transpose 
                {
                    (\(Vector.components.cartesian.prefix(n).map{ "column.\($0)" }.joined(separator: ", ")))
                } 
                
                /// static func SIMD\(n).diagonal(trimming:)
                /// ?:  SIMD.Transposable 
                /// - matrix:Square 
                /// - ->    :Self
                static 
                func diagonal(trimming matrix:Square) -> Self 
                {
                    .init(\(Vector.components.cartesian.prefix(n).enumerated()
                        .map{ "matrix.\($0.0).\($0.1)" }
                        .joined(separator: ", ")))
                }
                /// static func SIMD\(n).diagonal(padding:with:)
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
                            .init(\(Vector.components.cartesian.prefix(n).enumerated()
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
            /// ?:  SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
            /// - A     :Square 
            /// - ->    :Scalar 
            static 
            func determinant(_ A:Square) -> Scalar 
            {
                A.0 >|< A.1
            }
            /// static func SIMD2.inverse(_:)
            /// ?:  SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
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
            /// ?:  SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
            /// - A     :Square 
            /// - ->    :Scalar 
            static 
            func determinant(_ A:Square) -> Scalar 
            {
                A.0 >|< A.1 <> A.2
            }
            /// static func SIMD3.inverse(_:)
            /// ?:  SIMD.MatrixAlgebra where Scalar:BinaryFloatingPoint
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
    }
}
