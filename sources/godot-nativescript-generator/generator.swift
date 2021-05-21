extension Main.Generator 
{
    func run() 
    {
        Source.generate(file: self.outputClasses)
        {
            Source.text(from: "fragments", "external.swift.part")
            Source.text(from: "fragments", "runtime.swift.part")
            Source.text(from: "fragments", "variant.swift.part")
            
            Godot.swift 
        }
        Source.generate(file: self.outputCommon)
        {
            Source.text(from: "fragments", "dsl.swift.part")
            
            Vector.swift 
        }
    }
}