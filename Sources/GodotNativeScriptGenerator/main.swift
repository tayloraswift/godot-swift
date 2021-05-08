import ArgumentParser
import TSCBasic

extension AbsolutePath:ExpressibleByArgument 
{
    public
    init?(argument string:String)
    {
        if let base:Self = localFileSystem.currentWorkingDirectory
        {
            self.init(string, relativeTo: base)
        }
        else 
        {
            try? self.init(validating: string)
        }
    }
}

struct Main:ParsableCommand 
{ 
    struct Generator:ParsableCommand 
    {
        @Option(help: "the stage-independent output file to generate")
        var outputCommon:AbsolutePath
        @Option(help: "the stage-independent class definitions file to generate")
        var outputClasses:AbsolutePath
        
        static 
        var configuration:CommandConfiguration = .init(
            commandName: "generate",
            abstract: "Generate stage-independent code.")
    }
    
    struct Synthesizer:ParsableCommand 
    {
        @Option(help: "the workspace directory for this tool")
        var workspace:AbsolutePath
        
        @Option(help: "the stage-dependent output file to generate")
        var output:AbsolutePath
        
        @Option(help: "the name of the target")
        var target:String
        //@Option(help: "the name of the module")
        //var module:String
        @Option(help: "the path to the package")
        var packagePath:AbsolutePath
        
        static 
        var configuration:CommandConfiguration = .init(
            commandName: "synthesize",
            abstract: "Generate stage-dependent code.")
    }
    
    static 
    var configuration:CommandConfiguration = .init(
        abstract: "Generate code for godot-swift.",
        subcommands: [Generator.self, Synthesizer.self],
        defaultSubcommand: Generator.self)
}

Main.main()
