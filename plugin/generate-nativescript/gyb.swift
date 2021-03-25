import TSCBasic

struct Source
{
    @resultBuilder
    struct Code 
    {
    }
    
    let file:AbsolutePath
    let code:String 
    
    static 
    func fragment(indent tabs:Int = 0, @Code generator:() -> String) -> String 
    {
        generator().split(separator: "\n", omittingEmptySubsequences: false).map 
        {
            "\(String.init(repeating: " ", count: 4 * tabs))\($0)"
        }.joined(separator: "\n")
    }
    
    static 
    func block(extraIndendation tabs:Int = 0, delimiters:(String, String) = ("{", "}"),
        @Code generator:() -> String) 
        -> String 
    {
        Self.fragment(indent: tabs) 
        {
            """
            \(delimiters.0)
            """
            Self.fragment(indent: 1) 
            {
                generator()
            }
            """
            \(delimiters.1)
            """
        }
    }
    
    static 
    func code(file:AbsolutePath, @Code generator:() -> String) -> Self 
    {
        .init(file: file, code: generator())
    }
    
    static 
    func generate(file:AbsolutePath, @Code generator:() -> String) 
    {
        Self.init(file: file, code: generator()).emit()
    }
    
    func emit(filesystem:FileSystem = TSCBasic.localFileSystem) 
    {
        guard let _:Void = try? filesystem.writeFileContents(self.file, 
            bytes: .init(encodingAsUTF8: self.code), 
            atomically: true)
        else 
        {
            fatalError("failed to write to output file '\(self.file)'")
        }
    }
}

extension Source.Code 
{
    static 
    func buildExpression(_ block:String) -> [String]
    {
        [block]
    }
    static 
    func buildBlock(_ blocks:[String]...) -> [String]
    {
        .init(blocks.joined())
    }
    static 
    func buildOptional(_ block:[String]?) -> [String]
    {
        block ?? []
    }
    static 
    func buildEither(first block:[String]) -> [String]
    {
        block 
    }
    static 
    func buildEither(second block:[String]) -> [String]
    {
        block 
    }
    static 
    func buildArray(_ blocks:[[String]]) -> [String]
    {
        .init(blocks.joined() )
    }
    static 
    func buildFinalResult(_ blocks:[String]) -> String
    {
        blocks.joined(separator: "\n") 
    }
}
