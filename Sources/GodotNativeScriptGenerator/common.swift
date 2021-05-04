import struct TSCBasic.AbsolutePath

enum Synthesizer 
{
    static 
    func generate(common:AbsolutePath, classes:AbsolutePath)
    {
        Source.generate(file: classes)
        {
            Source.text(from: "fragments", "external.swift.part")
            Source.text(from: "fragments", "runtime.swift.part")
            Source.text(from: "fragments", "variant.swift.part")
            
            Godot.swift 
        }
        Source.generate(file: common)
        {
            Source.text(from: "fragments", "dsl.swift.part")
            
            Vector.swift 
        }
    }
}
