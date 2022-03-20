enum Grammar 
{
    typealias Parsable = _GrammarParsable
    
    struct ParsingError:Swift.Error, CustomStringConvertible 
    {
        let source:String, 
            problem:Range<String.Index>, 
            expected:Any.Type
        
        var description:String 
        {
            let head:Substring? = 
                self.source[..<self.problem.lowerBound].split(separator: "\n").last 
            let body:Substring  = 
                self.source[self.problem]
            let tail:Substring? = 
                self.source[self.problem.upperBound...].split(separator: "\n").first 
            return 
                """
                could not parse substring 
                '''
                \(head.map(String.init(_:)) ?? "")
                \(body)
                \(String.init(repeating: "~", count: body.count))
                \(tail.map(String.init(_:)) ?? "")
                '''
                as expected type `\(self.expected)`
                """
        }
    }
    
    struct Input 
    {
        let string:String 
        var index:String.Index 
        
        init(_ string:String)
        {
            self.string = string 
            self.index  = string.startIndex
        }
        
        mutating 
        func next() -> Character?
        {
            guard self.index != self.string.endIndex
            else 
            {
                return nil 
            }
            defer 
            {
                self.index = self.string.index(after: self.index)
            }
            return self.string[self.index]
        }
        
        func expected(_ type:Any.Type, from start:String.Index? = nil) -> ParsingError 
        {
            if let start:String.Index = start 
            {
                return .init(source: self.string, 
                    problem:    start ..< self.index, 
                    expected:   type)
            }
            else if self.index == self.string.startIndex 
            {
                return .init(source: self.string, 
                    problem:    self.string.startIndex ..< self.index, 
                    expected:   type)
            }
            else 
            {
                return .init(source: self.string, 
                    problem:    self.string.index(before: self.index) ..< self.index, 
                    expected:   type)
            }
        }
    }
}

protocol _GrammarParsable 
{
    typealias Terminal          = _GrammarParsableTerminal
    typealias CharacterClass    = _GrammarParsableCharacterClass
    
    init(parsing input:inout Grammar.Input) throws 
}
protocol _GrammarParsableTerminal:Grammar.Parsable
{
    static 
    var token:String 
    {
        get 
    }
    
    init()
}
protocol _GrammarParsableCharacterClass:Grammar.Parsable
{
    init?(_ character:Character)
}

extension Grammar.Parsable.CharacterClass 
{
    init(parsing input:inout Grammar.Input) throws 
    {
        guard   let character:Character = input.next(),
                let value:Self          = Self.init(character) 
        else 
        {
            throw input.expected(Self.self)
        }
        self = value
    }
}

extension Grammar.Parsable.Terminal
{
    init(parsing input:inout Grammar.Input) throws 
    {
        let start:String.Index = input.index
        for expected:Character in Self.token 
        {
            guard   let character:Character = input.next(), 
                        character == expected 
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
        self.init()
    }
}

extension Optional:Grammar.Parsable where Wrapped:Grammar.Parsable 
{
    init(parsing input:inout Grammar.Input)  
    {
        let reset:String.Index = input.index 
        if let wrapped:Wrapped = try? Wrapped.init(parsing: &input)
        {
            self = wrapped 
        }
        else 
        {
            input.index = reset 
            self = nil 
        }
    }
    
    // can’t be declared as protocol extension because then it would have to 
    // be marked `throws`
    init(parsing string:String)
    {
        var input:Grammar.Input = .init(string)
        self = Self.init(parsing: &input)
    }
}

extension Array:Grammar.Parsable where Element:Grammar.Parsable
{
    init(parsing input:inout Grammar.Input)
    {
        self.init()
        while let next:Element = .init(parsing: &input) 
        {
            self.append(next)
        }
    }
    
    init(parsing string:String)
    {
        var input:Grammar.Input = .init(string)
        self.init(parsing: &input)
        if input.index != input.string.endIndex 
        {
            print("warning: unparsed trailing characters '\(input.string[input.index...])'") 
        }
    }
}

struct List<Head, Body>:Grammar.Parsable where Head:Grammar.Parsable, Body:Grammar.Parsable
{
    let head:Head,
        body:Body
    
    init(parsing input:inout Grammar.Input) throws 
    {
        self.head = try .init(parsing: &input)
        self.body = try .init(parsing: &input)
    }
} 
