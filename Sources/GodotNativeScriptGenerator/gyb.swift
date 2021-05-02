import TSCBasic

enum Source
{
    @resultBuilder
    struct Code 
    {
    }
    
    static 
    func fragment(indent tabs:Int = 0, @Code generator:() -> String) -> String 
    {
        generator().split(separator: "\n", omittingEmptySubsequences: false).map 
        {
            "\(String.init(repeating: " ", count: 4 * tabs))\($0)"
        }.joined(separator: "\n")
    }
    
    private static 
    func inline(_ elements:[String], delimiters:(String, String), else empty:String? = nil) 
        -> String 
    {
        if let empty:String = empty, elements.isEmpty 
        {
            return empty 
        } 
        else 
        {
            return "\(delimiters.0)\(elements.joined(separator: ", "))\(delimiters.1)"
        }
    }
    static 
    func inline(angled:[String], else empty:String? = nil) -> String 
    {
        Self.inline(angled, delimiters: ("<", ">"), else: empty)
    }
    static 
    func inline(bracketed:[String], else empty:String? = nil) -> String 
    {
        Self.inline(bracketed, delimiters: ("[", "]"), else: empty)
    }
    static 
    func inline(list:[String], else empty:String? = nil) -> String 
    {
        Self.inline(list, delimiters: ("(", ")"), else: empty)
    }
    static 
    func constraints(_ constraints:[String]) -> String 
    {
        switch constraints.count 
        {
        case 0:
            return ""
        case 1:
            return 
                """
                
                    where \(constraints.joined(separator: ", "))
                """
        default: 
            return 
                """
                
                    where   \(constraints.joined(separator: ", \n            "))
                """
        }
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
    func text(from components:String..., relativeTo caller:String = #filePath) -> String 
    {
        let path:AbsolutePath           = .init(caller).parentDirectory.appending(components: components)
        guard let contents:ByteString   = try? TSCBasic.localFileSystem.readFileContents(path)
        else 
        {
            fatalError("could not find or read file '\(path)'")
        }
        return contents.description
    }
    
    static 
    func section(name:String..., @Code generator:() -> String) -> String 
    {
        guard let file:String = name.last 
        else 
        {
            fatalError("empty section name")
        }
        
        let directory:AbsolutePath  = .init(#filePath).parentDirectory
            .appending(component: ".gyb") 
            .appending(components: name.dropLast())
        guard let _:Void            = try? TSCBasic.localFileSystem
            .createDirectory(directory, recursive: true)
        else 
        {
            fatalError("could not create directory '\(directory)'")
        }
        
        return Self.generate(file: directory.appending(component: file), generator: generator)
    }
    
    @discardableResult
    static 
    func generate(file:AbsolutePath, filesystem:FileSystem = TSCBasic.localFileSystem, 
        @Code generator:() -> String) -> String
    {
        if file.extension != "part" 
        {
            print(bold: "generating file '\(file.basename)'")
            print(note: "in directory '\(file.parentDirectory)'")
        }
        
        let code:String     = generator()
        let new:ByteString  = .init(encodingAsUTF8: code)
        // avoid overwriting the file if it is unchanged 
        if  let old:ByteString = try? filesystem.readFileContents(file), 
            old == new 
        {
            return code 
        }
        else 
        {
            print(note: "file '\(file.basename)' changed, recompiling")
        }
        
        guard let _:Void = 
            try? filesystem.writeFileContents(file, bytes: new, atomically: true)
        else 
        {
            fatalError("failed to write to output file '\(file)'")
        }
        return code 
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
