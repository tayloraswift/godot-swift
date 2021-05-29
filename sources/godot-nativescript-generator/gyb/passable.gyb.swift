enum Passable 
{
    @Source.Code 
    static 
    var swift:String 
    {
        // generate `Godot.Function.Passable` conformances 
        """
        // “icall” types. these are related, but orthogonal to `Variant`/`VariantRepresentable`
        extension Godot 
        {
            struct Function 
            {
                fileprivate 
                typealias Passable = _GodotFunctionPassable
                
                private 
                let function:UnsafeMutablePointer<godot_method_bind>
            }
        }
        fileprivate 
        protocol _GodotFunctionPassable
        {
            associatedtype RawValue 
            
            static 
            func take(_ body:(UnsafeMutablePointer<RawValue>) -> ()) -> Self 
            func pass(_ body:(UnsafePointer<RawValue>?) -> ())
        }
        extension Godot.Function.Passable 
            where RawValue:Godot.RawAggregate, RawValue.Unpacked == Self
        {
            static 
            func take(_ body:(UnsafeMutablePointer<RawValue>) -> ()) -> Self 
            {
                RawValue.init(with: body).unpacked
            }
            
            func pass(_ body:(UnsafePointer<RawValue>?) -> ())
            {
                withUnsafePointer(to: .init(packing: self), body)
            }
        }
        
        // variant existential container, since protocols cannot directly 
        // conform to other protocols 
        extension Godot
        {
            fileprivate 
            struct VariantExistential 
            {
                let variant:Variant?
            }
        }
        extension Godot.VariantExistential:Godot.Function.Passable 
        {
            static 
            func take(_ body:(UnsafeMutablePointer<godot_variant>) -> ()) -> Self 
            {
                var unmanaged:Godot.Unmanaged.Variant = .init(with: body)
                defer 
                {
                    unmanaged.release()
                }
                return .init(variant: unmanaged.take(unretained: Godot.Variant?.self))
            }
            func pass(_ body:(UnsafePointer<godot_variant>?) -> ()) 
            {
                Godot.Unmanaged.Variant.pass(guaranteeing: self.variant, body)
            }
        }
        extension Optional:Godot.Function.Passable where Wrapped:Godot.AnyDelegate
        {
            // for some reason, godot bound methods return objects as double pointers, 
            // but pass them as direct pointers
            static 
            func take(_ body:(UnsafeMutablePointer<UnsafeMutableRawPointer?>) -> ()) -> Self 
            {
                var core:UnsafeMutableRawPointer? = nil 
                body(&core)
                // assume caller has already retained the object
                if  let core:UnsafeMutableRawPointer    = core,
                    let delegate:Wrapped                = 
                    Godot.type(of: core).init(retained: core) as? Wrapped
                {
                    return delegate
                }
                else 
                {
                    return nil 
                }
            }
            func pass(_ body:(UnsafePointer<UnsafeMutableRawPointer?>?) -> ())
            {
                withExtendedLifetime(self)
                {
                    body(self?.core.bindMemory(to: UnsafeMutableRawPointer?.self, capacity: 1))
                }
            }
        }
        """
        for swift:String in ["Bool", "Int64", "Float64"] 
        {
            "extension \(swift):Godot.Function.Passable"
            Source.block 
            {
                """
                static 
                func take(_ body:(UnsafeMutablePointer<Self>) -> ()) -> Self 
                {
                    var value:Self = .init()
                    body(&value)
                    return value
                }
                func pass(_ body:(UnsafePointer<Self>?) -> ())
                {
                    withUnsafePointer(to: self, body)
                }
                """
            }
        }
        """
        extension Vector:Godot.Function.Passable 
            where Storage:Godot.VectorStorage, Storage.VectorAggregate.Unpacked == Self
        {
            typealias RawValue = Storage.VectorAggregate
        }
        extension Vector.Rectangle:Godot.Function.Passable 
            where Storage:Godot.RectangleStorage, Storage.RectangleAggregate.Unpacked == Self
        {
            typealias RawValue = Storage.RectangleAggregate
        }
        """
        for (swift, godot, conditions):(String, String, String) in 
        [
            ("Quaternion",              "godot_quat",       "where T == Float32"),
            ("Godot.Plane3",            "godot_plane",      "where T == Float32"),
            ("Godot.Transform2.Affine", "godot_transform2d","where T == Float32"),
            ("Godot.Transform3.Affine", "godot_transform",  "where T == Float32"),
            ("Godot.Transform3.Linear", "godot_basis",      "where T == Float32"),
            ("Godot.ResourceIdentifier","godot_rid",        ""),
        ]
        {
            """
            extension \(swift):Godot.Function.Passable \(conditions)
            {
                typealias RawValue = \(godot)
            }
            """
        }
        for (swift, godot):(String, String) in 
        [
            ("Godot.List",      "godot_array"),
            ("Godot.Map",       "godot_dictionary"),
            ("Godot.NodePath",  "godot_node_path"),
            ("Godot.String",    "godot_string"),
            ("Godot.Array",     "Element.RawArrayReference"),
        ]
        {
            """
            extension \(swift):Godot.Function.Passable 
            {
                static 
                func take(_ body:(UnsafeMutablePointer<\(godot)>) -> ()) -> Self 
                {
                    .init(retained: .init(with: body))
                }
                func pass(_ body:(UnsafePointer<\(godot)>?) -> ())
                {
                    withExtendedLifetime(self)
                    {
                        withUnsafePointer(to: self.core, body)
                    }
                }
            }
            """
        }
        """
        /* extension String:Godot.Function.Passable 
        {
            static 
            func take(_ body:(UnsafeMutablePointer<godot_string>) -> ()) -> Self 
            {
                var core:godot_string = .init(with: body)
                defer 
                {
                    core.deinit()
                }
                return core.unpacked
            }
            func pass(_ body:(UnsafePointer<godot_string>?) -> ())
            {
                var core:godot_string = .init(packing: self)
                withUnsafePointer(to: core, body)
                core.deinit()
            }
        }
        extension Array:Godot.Function.Passable where Element:Godot.ArrayElement
        {
            static 
            func take(_ body:(UnsafeMutablePointer<Element.RawArrayReference>) -> ()) -> Self 
            {
                var core:Element.RawArrayReference = .init(with: body)
                defer 
                {
                    core.deinit()
                }
                return Element.convert(array: core)
            }
            func pass(_ body:(UnsafePointer<Element.RawArrayReference>?) -> ())
            {
                var core:Element.RawArrayReference = Element.convert(array: self)
                withUnsafePointer(to: core, body)
                core.deinit()
            }
        } */
        """
    }
}
