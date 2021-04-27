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
            // placeholders to make inert library compile 
            func <- <T, Function>(method:@escaping (T) -> Function, symbol:String) 
                -> Godot.NativeScriptInterface<T>.Method
                where T:Godot.NativeScript
            {
                Function.self
            }
            
            extension Godot.AnyDelegate 
            {
                final 
                func emit<Signal, T>(signal _:Signal.Value, as _:Signal.Type, from _:T.Type)
                    where Signal:Godot.Signal, T:Godot.NativeScript 
                {
                }
            }
            
            // inspection apis 
            extension Godot.NativeScript 
            {
                static 
                var __methods__:[String] 
                {
                    Self.interface.methods.map{ "\\($0)" }
                }
                static 
                var __signals__:[String]
                {
                    Self.interface.signals.map 
                    {
                        String.init(reflecting: $0)
                    }
                }
            }
            
            @_cdecl("\(Inspector.entrypoint)") 
            public 
            func \(Inspector.entrypoint)() -> UnsafeMutableRawPointer
            {
                let interfaces:[\(Inspector.Interface.self)] = 
                    Godot.Library.interface.types.map 
                {
                    (
                        type:       (.init(reflecting: $0.type), $0.symbols), 
                        methods:    $0.type.__methods__,
                        signals:    $0.type.__signals__
                    )
                }
                return Unmanaged<AnyObject>
                    .passRetained(interfaces as AnyObject)
                    .toOpaque()
            }
            """
        }
    }
}

#endif
