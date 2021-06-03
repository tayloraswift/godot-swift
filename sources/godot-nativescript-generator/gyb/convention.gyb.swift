enum Convention 
{
    static 
    func swift(arity max:Int) -> String 
    {
        // all declarations in this file should be `fileprivate`
        Source.fragment
        {
            // generate `Godot.Function.Passable` conformances. 
            """
            // “icall” types. these are related, but orthogonal to `Variant`/`VariantRepresentable`
            extension Godot 
            {
                fileprivate 
                struct Function 
                {
                    private 
                    let function:UnsafeMutablePointer<godot_method_bind>
                    
                    typealias Passable = _GodotFunctionPassable
                    
                    static 
                    func bind<T>(method:Swift.String, from _:T.Type) -> Self 
                        where T:AnyDelegate
                    {
                        guard let function:UnsafeMutablePointer<godot_method_bind> = 
                            Godot.api.1.0.godot_method_bind_get_method(T.symbol, method)
                        else 
                        {
                            fatalError("could not load method 'Godot::\\(T.symbol).\\(method)'")
                        }
                        return .init(function: function)
                    }
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
                fileprivate static 
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
                fileprivate 
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
                """
                extension \(swift):Godot.Function.Passable
                """
                Source.block 
                {
                    """
                    fileprivate static 
                    func take(_ body:(UnsafeMutablePointer<Self>) -> ()) -> Self 
                    {
                        var value:Self = .init()
                        body(&value)
                        return value
                    }
                    fileprivate 
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
                fileprivate
                typealias RawValue = Storage.VectorAggregate
            }
            extension Vector.Rectangle:Godot.Function.Passable 
                where Storage:Godot.RectangleStorage, Storage.RectangleAggregate.Unpacked == Self
            {
                fileprivate 
                typealias RawValue = Storage.RectangleAggregate
            }
            """
            for (swift, godot, conditions):(String, String, String) in 
            [
                // need to specify both type constraints separately, even though 
                // it creates a compiler warning (otherwise the compiler crashes)
                ("Vector.Plane",            "godot_plane",      "where Storage == SIMD3<T>, T == Float32"),
                ("Quaternion",              "godot_quat",       "where T == Float32"),
                ("Godot.Transform2.Affine", "godot_transform2d","where T == Float32"),
                ("Godot.Transform3.Affine", "godot_transform",  "where T == Float32"),
                ("Godot.Transform3.Linear", "godot_basis",      "where T == Float32"),
                ("Godot.ResourceIdentifier","godot_rid",        ""),
            ]
            {
                """
                extension \(swift):Godot.Function.Passable \(conditions)
                {
                    fileprivate 
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
                    fileprivate static 
                    func take(_ body:(UnsafeMutablePointer<\(godot)>) -> ()) -> Self 
                    {
                        .init(retained: .init(with: body))
                    }
                    fileprivate 
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
            extension Godot.Function 
            """
            Source.block 
            {
                """
                func callAsFunction(self delegate:Godot.AnyDelegate, variants:[Godot.Unmanaged.Variant]) 
                {
                    withExtendedLifetime(delegate) 
                    {
                        variants.withUnsafeBufferPointer
                        {
                            $0.withMemoryRebound(to: godot_variant.self) 
                            {
                                guard let base:UnsafePointer<godot_variant> = $0.baseAddress 
                                else 
                                {
                                    return 
                                }
                                var pointers:[UnsafePointer<godot_variant>?] = $0.indices.map 
                                {
                                    base + $0
                                }
                                // discard the return value 
                                var result:godot_variant = pointers.withUnsafeMutableBufferPointer 
                                {
                                    Godot.api.1.0.godot_method_bind_call(self.function, delegate.core, 
                                        $0.baseAddress, .init($0.count), nil)
                                }
                                Godot.api.1.0.godot_variant_destroy(&result)
                            }
                        }
                    }
                }
                """
                for arity:Int in 0 ... max 
                {
                    for void:Bool in [true, false] 
                    {
                        let generics:[String]   = (0 ..< arity).map{ "U\($0)" } + (void ? [] : ["V"])
                        let arguments:[String]  = ["self delegate:Godot.AnyDelegate"] + (0 ..< arity).map 
                        {
                            "_ u\($0):U\($0)"
                        }
                        """
                        fileprivate
                        func callAsFunction\(Source.inline(angled: generics, else: ""))\
                        \(Source.inline(list: arguments)) \(void ? "" : "-> V ")\ 
                        \(Source.constraints(generics.map{ "\($0):Passable" }))
                        """
                        Source.block 
                        {
                            if void 
                            {
                                Self.nest(level: 0, arity: arity, result: "nil")
                            }
                            else 
                            {
                                ".take"
                                Source.block 
                                {
                                    "(result:UnsafeMutablePointer<V.RawValue>) in "
                                    Self.nest(level: 0, arity: arity, result: ".init(result)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private static 
    func nest(level:Int, arity:Int, result:String) -> String 
    {
        return Source.fragment 
        {
            if      arity == 0
            {
                """
                withExtendedLifetime(delegate)
                {
                    Godot.api.1.0.godot_method_bind_ptrcall(self.function, 
                        delegate.core, nil, \(result))
                }
                """
            }
            else if arity == level 
            {
                """
                withExtendedLifetime(delegate)
                """
                Source.block
                {
                    """
                    var arguments:[UnsafeRawPointer?] = 
                    """
                    Source.block(delimiters: ("[", "]"))
                    {
                        for i:Int in 0 ..< arity 
                        {
                            ".init(u\(i)),"
                        }
                    }
                    """
                    arguments.withUnsafeMutableBufferPointer 
                    {
                        Godot.api.1.0.godot_method_bind_ptrcall(self.function, 
                            delegate.core, $0.baseAddress, \(result))
                    }
                    """
                }
            }
            else 
            {
                "u\(level).pass"
                Source.block 
                {
                    "(u\(level):UnsafePointer<U\(level).RawValue>?) in "
                    nest(level: level + 1, arity: arity, result: result)
                }
            }
        }
    }
}
