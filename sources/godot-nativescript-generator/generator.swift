extension Main.Generator 
{
    func run() 
    {
        Source.generate(file: self.outputClasses)
        {            
            Godot.swift 
        }
        Source.generate(file: self.outputCommon)
        {
            Source.text(from: "gyb", "fragments", "dsl.swift.part")
            
            Source.text(from: "gyb", "fragments", "quaternion.swift.part")
            Vector.swift 
        }
    }
}
