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
            /// :   Godot.VariantRepresentable  where Storage == SIMD3<T>
            /// :   Godot.Variant               where Storage == SIMD3<Float32>
            /// ?   where Storage:SIMD.Extendable, T:BinaryFloatingPoint
            ///     An *n*-dimensional plane.
            /// 
            ///     When [`Storage`] is [[`SIMD3<Float32>`]], this type corresponds 
            ///     to the 
            ///     [`Godot::Plane`](https://docs.godotengine.org/en/stable/classes/class_plane.html) 
            ///     type in GDScript.
            /// 
            ///     Create a plane from a normal vector and a perpendicular distance 
            ///     from the origin with the [`init(normal:bias:)`] initializer:
            /**
                    ```swift 
                    let normal:Vector3<T>       = ... ,
                        bias:T                  = ... 
                    let plane:Vector3<T>.Plane  = .init(normal: normal, bias: bias)
                    ```
            **/
            ///     Access the normal vector and distance from the origin through 
            ///     the [`normal`] and [`bias`] properties:
            /**
                    ```swift 
                    let plane:Vector3<T>.Plane  = ...
                    let normal:Vector3<T>       = plane.normal, 
                        bias:T                  = plane.bias 
                    ```
            **/
            ///     You can convert between floating point precisions with the 
            ///     [`init(_:)#(arity-3)`] initializer:
            /**
                    ```swift 
                    let float64:Vector3<Float64>.Plane = ... 
                    let float32:Vector3<Float32>.Plane = .init(float64)
                    ```
            **/
            /// #   [Creating a plane](vector-plane-initializer-usage)
            /// #   [Converting planes between scalar types](vector-plane-type-conversion-usage)
            /// #   [Getting vector representations of a plane](vector-plane-accessors)
            /// #   (0:vector-plane)
            /// #   (7:math-types)
            /// #   (21:godot-core-types)
            /// #   (21:)
            struct Plane:Hashable
            {
                /// let Vector.Plane.affine:Vector<Storage.Extended, T>
                ///     The affine vector representation of this plane. The 
                ///     first *n* elements are its [`normal`], and the last 
                ///     element is its [`bias`].
                /// #   (2:vector-plane-accessors)
                let affine:Vector<Storage.Extended, T> 
                
                /// var Vector.Plane.bias:T { get }
                ///     The perpendicular distance of this plane from the origin.
                /// #   (0:vector-plane-accessors)
                var bias:T 
                {
                    Storage.bias(of: self.affine.storage)
                } 
                /// var Vector.Plane.normal:Vector<Storage, T> { get }
                ///     The normal vector specifying the direction this plane faces.
                /// #   (1:vector-plane-accessors)
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
                /// #   (0:vector-plane-initializer-usage)
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
                /// #   (1:vector-plane-initializer-usage)
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
                /// - other :Vector\(n)<U>.Plane
                /// #   (\(n):vector-plane-type-conversion-usage)
                /// #   (arity-\(n))
                init<U>(_ other:Vector\(n)<U>.Plane) 
                    where U:BinaryFloatingPoint
                {
                    self.init(affine: Vector<Storage.Extended, T>.init(other.affine))
                }
                """
            }
        }
    }
}
