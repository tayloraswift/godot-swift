import ArgumentParser
import TSCBasic

struct Generator: ParsableCommand {
    @Option(help: "the stage-independent output file to generate")
    var outputCommon: AbsolutePath
    @Option(help: "the stage-independent class definitions file to generate")
    var outputClasses: AbsolutePath

    static var configuration = CommandConfiguration(
        commandName: "generate",
        abstract: "Generate stage-independent code."
    )

    func run() throws {
        Source.generate(file: self.outputClasses) { Godot.swift }
        Source.generate(file: self.outputCommon) {
            Source.text(from: "gyb", "dsl.swift.part")
            Source.section(name: "simd-protocols.swift.part") { SIMDProtocols.swift }
            Source.section(name: "vector.swift.part") { Vector.swift }
            Source.section(name: "rectangle.swift.part") { Rectangle.swift }
            Source.section(name: "plane.swift.part") { Plane.swift }
            Source.text(from: "gyb", "common-types", "quaternion.swift.part")
            Source.text(from: "gyb", "common-types", "transform.swift.part")
        }
    }
}
