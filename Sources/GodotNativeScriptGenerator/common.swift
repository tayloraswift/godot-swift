import struct TSCBasic.AbsolutePath

enum Synthesizer 
{
    static 
    func generate(common:AbsolutePath)
    {
        Source.generate(file: common)
        {
            Source.text(from: "fragments", "external.swift.part")
            Source.text(from: "fragments", "runtime.swift.part")
            Source.text(from: "fragments", "variant.swift.part")
            Source.text(from: "fragments", "dsl.swift.part")
            
            Godot.swift 
            
            Vector.swift 
        }
    }
}
