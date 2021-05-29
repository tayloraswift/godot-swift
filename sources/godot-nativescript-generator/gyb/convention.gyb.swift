enum Convention 
{
    static 
    func swift(arity max:Int) -> String 
    {
        Source.fragment
        {
            """
            extension Godot.Function 
            """
            Source.block 
            {
                """
                func callAsFunction(delegate:Godot.AnyDelegate, variants:[Godot.Unmanaged.Variant]) 
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
