enum Plane 
{
    @Source.Code 
    static 
    var swift:String 
    {
        """
        extension Vector where Storage:SIMD.Extendable, T:BinaryFloatingPoint
        """
        Source.block 
        {
            """
            /// struct Vector.Plane 
            /// :   Hashable 
            /// ?   where Storage:SIMD.Extendable, T:BinaryFloatingPoint
            ///     An *n*-dimensional plane.
            /// #   (7:math-types)
            struct Plane:Hashable
            {
                /// let Vector.Plane.affine:Vector<Storage.Extended, T>
                ///     The affine vector representation of this plane. The 
                ///     first *n* elements are its [`normal`], and the last 
                ///     element is its [`bias`].
                let affine:Vector<Storage.Extended, T> 
                
                /// var Vector.Plane.bias:T { get }
                ///     The perpendicular distance of this plane from the origin.
                var bias:T 
                {
                    Storage.bias(of: self.affine.storage)
                } 
                /// var Vector.Plane.normal:Vector<Storage, T> { get }
                ///     The normal vector specifying the direction this plane faces.
                var normal:Vector<Storage, T> 
                {
                    Vector<Storage, T>.init(storage: Storage.weights(of: self.affine.storage))
                }
                
                /// init Vector.Plane.init(affine:)
                ///     Creates a plane from an affine vector. 
                /// - affine:Vector<Storage.Extended, T>
                ///     An (*n*\\ +\\ 1)-dimensional vector whose first *n* 
                ///     components contain a normal vector, and whose last 
                ///     component specifies a distance from the origin.
                /// 
                ///     For some plane operations to be meaningful, the normal 
                ///     vector to be extracted from this parameter should be 
                ///     of unit length.
                init(affine:Vector<Storage.Extended, T>) 
                {
                    self.affine = affine
                }
                /// init Vector.Plane.init(normal:bias:)
                ///     Creates a plane from a normal vector and a distance from 
                ///     the origin. 
                /// - normal:Vector<Storage, T>
                ///     The normal vector specifying the direction the plane faces. 
                /// 
                ///     For some plane operations to be meaningful, this normal 
                ///     vector should be of unit length.
                /// - bias  :T 
                ///     The perpendicular distance of the plane from the origin.
                init(normal:Vector<Storage, T>, bias:T) 
                {
                    self.affine = normal || bias
                }
            }
            """
        }
        for n:Int in 2 ... 3 
        {
            """
            extension Vector.Plane where Storage == SIMD\(n)<T>
            """
            Source.block
            {
                """
                /// init Vector.Plane.init<U>(_:) 
                /// where U:BinaryFloatingPoint
                /// ?   where Storage == SIMD\(n)<T>
                ///     Converts a plane of scalar type [[`U`]] to a plane of 
                ///     scalar type [[`T`]].
                /// - other :Vector<SIMD\(n)<U>, U>.Plane
                /// #   (\(n):vector-plane-type-conversion-usage)
                init<U>(_ other:Vector<SIMD\(n)<U>, U>.Plane) 
                    where U:BinaryFloatingPoint
                {
                    self.init(affine: Vector<Storage.Extended, T>.init(other.affine))
                }
                """
            }
        }
    }
}
