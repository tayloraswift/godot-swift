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
            Source.text(from: "gyb",                    "dsl.swift.part")
            Source.section(name:                        "simd-protocols.swift.part")
            {
                SIMDProtocols.swift 
            }
            Source.section(name:                        "vector.swift.part")
            {
                Vector.swift 
            }
            Source.section(name:                        "rectangle.swift.part")
            {
                Rectangle.swift
            }
            Source.section(name:                        "plane.swift.part")
            {
                Plane.swift
            }
            Source.text(from: "gyb", "common-types",    "quaternion.swift.part")
            Source.text(from: "gyb", "common-types",    "transform.swift.part")
        }
    }
}
