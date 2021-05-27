enum VariantRaw 
{
    @Source.Code 
    static 
    var swift:String 
    {
        """
        extension Godot 
        {
            typealias RawValue      = _GodotRawValue
            typealias RawReference  = _GodotRawReference 
        }
        /// protocol Godot.RawValue 
        ///     A trivial GDScript type.
        /// 
        ///     Do not conform additional types to this protocol.
        /// #   (godot-core-protocols)
        protocol _GodotRawValue
        {
            init()
            
            static 
            var variantType:Godot.VariantType 
            {
                get 
            }
        }
        extension Godot.RawValue 
        {
            init(with initializer:(UnsafeMutablePointer<Self>) -> ()) 
            {
                self.init()
                initializer(&self)
            }
        }

        /// protocol Godot.RawReference
        /// :   Godot.RawValue 
        ///     A non-trivial GDScript type.
        /// 
        ///     Do not conform additional types to this protocol.
        /// #   (godot-core-protocols)
        protocol _GodotRawReference:Godot.RawValue
        {
            mutating
            func `deinit`()
        }
        """
        for (name, type, unpacked):(String, String, String) in 
        [
            ("vector2",         "vector2",              "Vector2<Float32>"), 
            ("vector3",         "vector3",              "Vector3<Float32>"), 
            ("color",           "vector4",              "Vector4<Float32>"), 
            ("quat",            "quaternion",           "Quaternion<Float32>"), 
            ("plane",           "plane3",               "Godot.Plane3<Float32>"), 
            ("rect2",           "rectangle2",           "Vector2<Float32>.Rectangle"), 
            ("aabb",            "rectangle3",           "Vector3<Float32>.Rectangle"), 
            ("transform2d",     "affine2",              "Godot.Transform2<Float32>.Affine"), 
            ("transform",       "affine3",              "Godot.Transform3<Float32>.Affine"), 
            ("basis",           "linear3",              "Godot.Transform3<Float32>.Linear"), 
            ("rid",             "resourceIdentifier",   "Godot.ResourceIdentifier"), 
        ]
        {
            """
            extension godot_\(name):Godot.RawValue 
            {
                static 
                var variantType:Godot.VariantType 
                {
                    .\(type)
                }
                static 
                func unpacked(variant:Godot.Unmanaged.Variant) -> \(unpacked)? 
                {
                    variant.load(where: Self.variantType)
                    {
                        Godot.api.1.0.godot_variant_as_\(name)($0).unpacked
                    } 
                }
                static 
                func variant(packing value:\(unpacked)) -> Godot.Unmanaged.Variant
                {
                    withUnsafePointer(to: Self.init(packing: value)) 
                    {
                        .init(value: $0, Godot.api.1.0.godot_variant_new_\(name))
                    }
                }
            }
            """
        }
        for (name, type):(String, String) in 
        [
            ("node_path",           "nodePath"), 
            ("string",              "string"), 
            ("array",               "list"), 
            ("dictionary",          "map"), 
            ("pool_byte_array",     "uint8Array"), 
            ("pool_int_array",      "int32Array"),
            ("pool_real_array",     "float32Array"),
            ("pool_string_array",   "stringArray"),
            ("pool_vector2_array",  "vector2Array"),
            ("pool_vector3_array",  "vector3Array"),
            ("pool_color_array",    "vector4Array"),
        ]
        {
            """
            extension godot_\(name):Godot.RawReference
            {
                mutating 
                func `deinit`()
                {
                    Godot.api.1.0.godot_\(name)_destroy(&self)
                }
                
                static 
                var variantType:Godot.VariantType 
                {
                    .\(type)
                }
            }
            """
        }
    }
}
