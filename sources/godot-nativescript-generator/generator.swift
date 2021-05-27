extension Main.Generator 
{
    func run() 
    {
        Source.generate(file: self.outputClasses)
        {
            Source.text(from: "fragments", "external.swift.part")
            Source.text(from: "fragments", "runtime.swift.part")
            Source.text(from: "fragments", "variant.swift.part")
            
            Source.section(name: "variant-raw.swift.part")
            {
                VariantRaw.swift
            }
            Source.section(name: "variant-vector.swift.part")
            {
                VariantVector.swift
            }
            Source.section(name: "variant-rectangle.swift.part")
            {
                VariantRectangle.swift
            }
            Source.section(name: "variant-array.swift.part")
            {
                VariantArray.swift
            }
            
            Godot.swift 
        }
        Source.generate(file: self.outputCommon)
        {
            Source.text(from: "fragments", "dsl.swift.part")
            
            Vector.swift 
        }
    }
}
