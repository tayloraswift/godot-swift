protocol _GrammarParseable 
{
    typealias Terminal          = _GrammarParseableTerminal
    typealias CharacterClass    = _GrammarParseableCharacterClass
    
    init(parsing:String, from position:inout String.Index) throws 
}
protocol _GrammarParseableTerminal:Grammar.Parseable
{
    static 
    var token:String 
    {
        get 
    }
    
    init()
}
protocol _GrammarParseableCharacterClass:Grammar.Parseable
{
    init?(character:Character)
}

enum Grammar 
{
    typealias Parseable = _GrammarParseable
    
    enum ParsingError:Swift.Error 
    {
        case unexpectedEOS(expected:Parseable.Type)
        case unexpected(String, expected:Parseable.Type)
    }
}

extension Grammar.Parseable.CharacterClass 
{
    init(parsing string:String, from position:inout String.Index) throws 
    {
        guard position < string.endIndex
        else 
        {
            throw Grammar.ParsingError.unexpectedEOS(expected: Self.self)
        }
        
        let character:Character = string[position]
        guard let element:Self  = .init(character: character) 
        else 
        {
            throw Grammar.ParsingError.unexpected(.init(character), expected: Self.self)
        }
        
        string.formIndex(after: &position)
        self = element
    }
}

extension Grammar.Parseable.Terminal
{
    init(parsing string:String, from position:inout String.Index) throws 
    {
        let start:String.Index = position
        for character:Character in Self.token 
        {
            guard position < string.endIndex 
            else 
            {
                throw Grammar.ParsingError.unexpectedEOS(expected: Self.self)
            }
            
            guard character == string[position] 
            else 
            {
                throw Grammar.ParsingError.unexpected(.init(string[start ... position]), expected: Self.self)
            }
            
            string.formIndex(after: &position)
        }
        self.init()
    }
}

extension Optional:Grammar.Parseable where Wrapped:Grammar.Parseable 
{
    // need to write it like this because swift gets confused by failable 
    // inits on Optional<T>
    private static 
    func parse(_ string:String, from position:inout String.Index) -> Self 
    {
        let reset:String.Index = position 
        do 
        {
            return .some(try .init(parsing: string, from: &position))
        }
        catch 
        {
            position = reset 
            return nil 
        }
    }
    
    init(parsing string:String, from position:inout String.Index)
    {
        self = .parse(string, from: &position)
    }
    
    // can’t be declared as protocol extension because then it would have to 
    // be marked `throws`
    init(parsing string:String)
    {
        var index:String.Index = string.startIndex
        self = .parse(string, from: &index)
    }
}

extension Array:Grammar.Parseable where Element:Grammar.Parseable
{
    init(parsing string:String, from position:inout String.Index)
    {
        self.init()
        while let next:Element = .init(parsing: string, from: &position) 
        {
            self.append(next)
        }
    }
    
    init(parsing string:String)
    {
        var index:String.Index = string.startIndex 
        self.init(parsing: string, from: &index)
        if index == string.endIndex 
        {
            return 
        }
        
        let parsed:Int = string.distance(from: string.startIndex, to: index)
        let count:Int  = string.count 
        
        let display:String 
        if count > 32 
        {
            display = string 
        }
        else 
        {
            display = "\(String.init(string.prefix(32))) ... "
        }
        
        print("warning: did not fully parse '\(display)' (consumed \(parsed) of \(count) characters)")
    }
}

struct List<Head, Body>:Grammar.Parseable where Head:Grammar.Parseable, Body:Grammar.Parseable
{
    let head:Head,
        body:Body
    
    init(parsing string:String, from position:inout String.Index) throws 
    {
        self.head = try .init(parsing: string, from: &position)
        self.body = try .init(parsing: string, from: &position)
    }
} 
