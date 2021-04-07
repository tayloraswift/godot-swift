#if BUILD_STAGE_INERT 

import struct TSCBasic.AbsolutePath

extension Synthesizer 
{
    static 
    func generate(staged:AbsolutePath)
    {
        Source.generate(file: staged)
        {
            """
            extension Godot 
            {
                fileprivate 
                enum __Synthesized__ 
                {
                    // static 
                    // var variadics:[Any.Type] = []
                }
            }
            
            extension Godot.AnyNativeScript 
            {
                static 
                var __signatures__:[String] 
                {
                    []
                }
            }
            extension Godot.NativeScript 
            {
                static 
                var __signatures__:[String] 
                {
                    Self.interface.methods.map{ "\\($0.witness)" }
                }
            }
            
            func <- <T>(property:Godot.NativeScriptInterface<T>.Witness.Property, symbol:String) 
                -> Godot.NativeScriptInterface<T>.Member
                where T:Godot.NativeScript
            {
                .property(witness: property, symbol: symbol)
            }
            func <- <T, Function>(method:@escaping (T) -> Function, symbol:String) 
                -> Godot.NativeScriptInterface<T>.Member
                where T:Godot.NativeScript
            {
                return .method(witness: Function.self, symbol: symbol)
            }
            
            extension Godot.__Synthesized__ 
            {
                static 
                func inspect() -> [(typename:String, symbols:[String], signatures:[String])]
                {
                    Godot.Library.interface.types.map 
                    {
                        (.init(reflecting: $0.type), $0.symbols, $0.type.__signatures__)
                    }
                }
            }
            
            @_cdecl("\(Inspector.entrypoint)") 
            public 
            func \(Inspector.entrypoint)() -> UnsafeMutableRawPointer
            {
                Unmanaged<AnyObject>.passRetained(Godot.__Synthesized__.inspect as AnyObject).toOpaque()
            }
            """
        }
    }
}

#endif
