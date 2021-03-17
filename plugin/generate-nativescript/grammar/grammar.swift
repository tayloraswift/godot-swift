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
/* 
enum Symbol 
{

    // Endline ::= ' ' * '\n'
    struct Endline:Parseable 
    {
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:[Token.Space] =     .parse(tokens, position: &position),
                _:Token.Newline = try .parse(tokens, position: &position)
            return .init()
        }
    }


    
    //  ModuleField         ::= 'module' <Whitespace> <Identifier> <Endline>
    struct ModuleField:Parseable 
    {
        struct Module:Parseable.Terminal 
        {
            static 
            let token:String = "module"
        }
        
        let identifier:String 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Module                        = try .parse(tokens, position: &position),
                _:Symbol.Whitespace             = try .parse(tokens, position: &position),
                identifier:Symbol.Identifier    = try .parse(tokens, position: &position),
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifier: identifier.string)
        }
    }
    
    // FunctionField       ::= <FunctionKeyword> <Whitespace> <Identifiers> <TypeParameters> ? '?' ? '(' ( <FunctionLabel> ':' ) * ')' <Endline>
    //                       | 'case' <Whitespace> <Identifiers> <Endline>
    // FunctionKeyword     ::= 'init'
    //                       | 'func'
    //                       | 'mutating' <Whitespace> 'func'
    //                       | 'static' <Whitespace> 'func'
    //                       | 'case' 
    //                       | 'indirect' <Whitespace> 'case' 
    // FunctionLabel       ::= <Identifier> 
    //                       | <Identifier> ? '...'
    // Identifiers         ::= <Identifier> ( '.' <Identifier> ) * ( '.' <EncapsulatedOperator> ) ?
    // TypeParameters      ::= '<' <Whitespace> ? <Identifier> <Whitespace> ? ( ',' <Whitespace> ? <Identifier> <Whitespace> ? ) * '>'
    struct FunctionField:Parseable, CustomStringConvertible
    {
        struct FunctionFieldNormal:Parseable
        {
            let keyword:Symbol.FunctionKeyword
            let identifiers:[String]
            let generics:[String] 
            let failable:Bool
            let labels:[(name:String, variadic:Bool)]
            
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                let keyword:Symbol.FunctionKeyword          = try .parse(tokens, position: &position), 
                    _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                    identifiers:Symbol.Identifiers          = try .parse(tokens, position: &position),
                    generics:Symbol.TypeParameters?         =     .parse(tokens, position: &position),
                    failable:Token.Question?                =     .parse(tokens, position: &position),
                    _:Token.Parenthesis.Left                = try .parse(tokens, position: &position),
                    labels:[List<Symbol.FunctionLabel, Token.Colon>] = .parse(tokens, position: &position),
                    _:Token.Parenthesis.Right               = try .parse(tokens, position: &position),
                    _:Symbol.Endline                        = try .parse(tokens, position: &position)
                return .init(keyword: keyword, 
                    identifiers:    identifiers.identifiers, 
                    generics:       generics?.identifiers ?? [], 
                    failable:       failable != nil, 
                    labels:         labels.map{ ($0.head.string, $0.head.variadic) })
            }
        }
        struct FunctionFieldUninhabitedCase:Parseable
        {
            let identifiers:[String]
            
            static 
            func parse(_ tokens:[Character], position:inout Int) throws -> Self
            {
                let _:Symbol.FunctionKeyword.Case           = try .parse(tokens, position: &position), 
                    _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                    identifiers:Symbol.Identifiers          = try .parse(tokens, position: &position),
                    _:Symbol.Endline                        = try .parse(tokens, position: &position)
                return .init(identifiers: identifiers.identifiers)
            }
        }
        
        let keyword:Symbol.FunctionKeyword
        let identifiers:[String]
        let generics:[String] 
        let failable:Bool
        let labels:[(name:String, variadic:Bool)]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if let normal:FunctionFieldNormal = .parse(tokens, position: &position) 
            {
                return .init(keyword: normal.keyword, identifiers: normal.identifiers, 
                    generics: normal.generics, failable: normal.failable, labels: normal.labels)
            }
            else if let `case`:FunctionFieldUninhabitedCase = .parse(tokens, position: &position) 
            {
                return .init(keyword: .case, identifiers: `case`.identifiers, 
                    generics: [], failable: false, labels: [])
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
        
        var description:String 
        {
            """
            FunctionField
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
                failable    : \(self.failable)
                labels      : \(self.labels)
            }
            """
        }
    }

    enum FunctionKeyword:Parseable 
    {
        struct Init:Parseable.Terminal 
        {
            static 
            let token:String = "init"
        }
        struct Func:Parseable.Terminal 
        {
            static 
            let token:String = "func"
        }
        struct Mutating:Parseable.Terminal 
        {
            static 
            let token:String = "mutating"
        }
        struct Case:Parseable.Terminal 
        {
            static 
            let token:String = "case"
        }
        struct Indirect:Parseable.Terminal 
        {
            static 
            let token:String = "indirect"
        }
        
        case `init` 
        case `func` 
        case mutatingFunc
        case staticFunc
        case `case`
        case indirectCase
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Init = .parse(tokens, position: &position)
            {
                return .`init`
            }
            else if let _:Func = .parse(tokens, position: &position)
            {
                return .func
            }
            else if let _:List<Mutating, List<Symbol.Whitespace, Func>> = 
                .parse(tokens, position: &position)
            {
                return .mutatingFunc
            }
            else if let _:List<Token.Static, List<Symbol.Whitespace, Func>> = 
                .parse(tokens, position: &position)
            {
                return .staticFunc
            }
            else if let _:Case = .parse(tokens, position: &position)
            {
                return .case
            }
            else if let _:List<Indirect, List<Symbol.Whitespace, Case>> = 
                .parse(tokens, position: &position)
            {
                return .indirectCase
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    struct FunctionLabel:Parseable, CustomStringConvertible
    {
        let string:String, 
            variadic:Bool 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let variadic:List<Symbol.Identifier?, Token.Ellipsis> = 
                .parse(tokens, position: &position)
            {
                return .init(string: variadic.head?.string ?? "_", variadic: true)
            }
            else if let singular:Symbol.Identifier = 
                .parse(tokens, position: &position)
            {
                return .init(string: singular.string, variadic: false)
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
        
        var description:String 
        {
            "\(self.variadic && self.string == "_" ? "" : self.string)\(self.variadic ? "..." : ""):"
        }
    }
    
    struct TypeParameters:Parseable, CustomStringConvertible
    {
        let identifiers:[String]
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Angle.Left          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position),
                head:Symbol.Identifier      = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position),
                body:[List<Token.Comma, List<Symbol.Whitespace?, List<Symbol.Identifier, Symbol.Whitespace?>>>] = 
                .parse(tokens, position: &position),
                _:Token.Angle.Right         = try .parse(tokens, position: &position)
            return .init(identifiers: ([head] + body.map(\.body.body.head)).map(\.string))
        }
        
        var description:String 
        {
            "<\(self.identifiers.joined(separator: ", "))>"
        }
    }
    
    // SubscriptField      ::= 'subscript' <Whitespace> <Identifiers> '[' ( <Identifier> ':' ) * ']' <Whitespace> ? <MemberMutability> <Endline> 
    struct SubscriptField:Parseable, CustomStringConvertible
    {
        struct Subscript:Parseable.Terminal 
        {
            static 
            let token:String = "subscript"
        }
        
        let identifiers:[String],
            labels:[String], 
            mutability:Symbol.MemberMutability
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Subscript                     = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position),
                identifiers:Symbol.Identifiers  = try .parse(tokens, position: &position),
                _:Token.Bracket.Left            = try .parse(tokens, position: &position),
                labels:[List<Symbol.Identifier, Token.Colon>] = .parse(tokens, position: &position),
                _:Token.Bracket.Right           = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position),
                mutability:Symbol.MemberMutability = try .parse(tokens, position: &position),
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifiers: identifiers.identifiers, 
                labels: labels.map(\.head.string), mutability: mutability)
        }
        
        var description:String 
        {
            """
            SubscriptField 
            {
                identifiers     : \(self.identifiers)
                labels          : \(self.labels)
            }
            """
        }
    }
    
    // MemberField         ::= <MemberKeyword> <Whitespace> <Identifiers> ( <Whitespace> ? ':' <Whitespace> ? <Type> ) ? ( <Whitespace> ? <MemberMutability> ) ? <Endline> 
    // MemberKeyword       ::= 'let'
    //                       | 'var'
    //                       | 'static' <Whitespace> 'let'
    //                       | 'static' <Whitespace> 'var'
    //                       | 'associatedtype'
    // MemberMutability    ::= '{' <Whitespace> ? 'get' ( ( <Whitespace> 'nonmutating' ) ? <Whitespace> 'set' ) ? <Whitespace> ? '}'
    struct MemberField:Parseable, CustomStringConvertible
    {
        let keyword:Symbol.MemberKeyword
        let identifiers:[String]
        let type:Symbol.SwiftType?
        let mutability:Symbol.MemberMutability?
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.MemberKeyword            = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                     = try .parse(tokens, position: &position),
                identifiers:Symbol.Identifiers          = try .parse(tokens, position: &position),
                type:List<Symbol.Whitespace?, List<Token.Colon, List<Symbol.Whitespace?, Symbol.SwiftType>>>? = 
                                                              .parse(tokens, position: &position),
                mutability:List<Symbol.Whitespace?, Symbol.MemberMutability>? = 
                                                              .parse(tokens, position: &position),
                _:Symbol.Endline                        = try .parse(tokens, position: &position)
            return .init(keyword: keyword, 
                identifiers:    identifiers.identifiers, 
                type:           type?.body.body.body,
                mutability:     mutability?.body)
        }
        
        var description:String 
        {
            """
            MemberField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                type        : \(self.type.map(String.init(describing:)) ?? "")
                mutability  : \(self.mutability.map(String.init(describing:)) ?? "")
            }
            """
        }
    }
    enum MemberKeyword:Parseable 
    {
        struct Let:Parseable.Terminal 
        {
            static 
            let token:String = "let"
        }
        struct Var:Parseable.Terminal 
        {
            static 
            let token:String = "var"
        }
        struct Associatedtype:Parseable.Terminal 
        {
            static 
            let token:String = "associatedtype"
        }
        
        case `let` 
        case `var` 
        case staticLet 
        case staticVar
        case `associatedtype`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Let = .parse(tokens, position: &position)
            {
                return .let
            }
            else if let _:Var = .parse(tokens, position: &position)
            {
                return .var 
            }
            else if let _:List<Token.Static, List<Symbol.Whitespace, Let>> = 
                .parse(tokens, position: &position)
            {
                return .staticLet 
            }
            else if let _:List<Token.Static, List<Symbol.Whitespace, Var>> = 
                .parse(tokens, position: &position)
            {
                return .staticVar
            }
            else if let _:Associatedtype = .parse(tokens, position: &position)
            {
                return .associatedtype
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    enum MemberMutability:Parseable 
    {
        struct Get:Parseable.Terminal 
        {
            static 
            let token:String = "get"
        }
        struct Nonmutating:Parseable.Terminal 
        {
            static 
            let token:String = "nonmutating"
        }
        struct Set:Parseable.Terminal 
        {
            static 
            let token:String = "set"
        }
        
        case get 
        case getset
        case nonmutatingset
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Brace.Left                  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?                =     .parse(tokens, position: &position),
                _:Get                               = try .parse(tokens, position: &position),
                mutability:List<List<Symbol.Whitespace, Nonmutating>?, List<Symbol.Whitespace, Set>>? =
                                                          .parse(tokens, position: &position),
                _:Symbol.Whitespace?                =     .parse(tokens, position: &position),
                _:Token.Brace.Right                 = try .parse(tokens, position: &position)
            guard let set:List<List<Symbol.Whitespace, Nonmutating>?, List<Symbol.Whitespace, Set>> = 
                mutability 
            else 
            {
                return .get 
            }
            guard let _:List<Symbol.Whitespace, Nonmutating> = set.head 
            else 
            {
                return .getset 
            }
            return .nonmutatingset
        }
    }
    
    
    
    // TypeField           ::= <TypeKeyword> <Whitespace> <Identifiers> <TypeParameters> ? <Endline>
    // TypeKeyword         ::= 'protocol'
    //                       | 'class'
    //                       | 'final' <Whitespace> 'class'
    //                       | 'struct'
    //                       | 'enum'
    struct TypeField:Parseable, CustomStringConvertible
    {
        let keyword:TypeKeyword 
        let identifiers:[String]
        let generics:[String]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let keyword:Symbol.TypeKeyword          = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace                 = try .parse(tokens, position: &position), 
                identifiers:Symbol.Identifiers      = try .parse(tokens, position: &position), 
                generics:Symbol.TypeParameters?     =     .parse(tokens, position: &position), 
                _:Symbol.Endline                    = try .parse(tokens, position: &position)
            return .init(keyword: keyword, identifiers: identifiers.identifiers, generics: generics?.identifiers ?? [])
        }
        
        var description:String 
        {
            """
            TypeField 
            {
                keyword     : \(self.keyword)
                identifiers : \(self.identifiers)
                generics    : \(self.generics)
            }
            """
        }
    }
    enum TypeKeyword:Parseable 
    {
        struct `Protocol`:Parseable.Terminal 
        {
            static 
            let token:String = "protocol"
        }
        struct Class:Parseable.Terminal 
        {
            static 
            let token:String = "class"
        }
        struct Struct:Parseable.Terminal 
        {
            static 
            let token:String = "struct"
        }
        struct Enum:Parseable.Terminal 
        {
            static 
            let token:String = "enum"
        }
        
        case `protocol` 
        case `class` 
        case finalClass 
        case `struct` 
        case `enum`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:Protocol = .parse(tokens, position: &position)
            {
                return .protocol
            }
            else if let _:Class = .parse(tokens, position: &position)
            {
                return .class 
            }
            else if let _:List<Token.Final, List<Symbol.Whitespace, Class>> = 
                .parse(tokens, position: &position)
            {
                return .finalClass 
            }
            else if let _:Struct = .parse(tokens, position: &position)
            {
                return .struct
            }
            else if let _:Enum = .parse(tokens, position: &position)
            {
                return .enum 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // TypealiasField      ::= 'typealias' <Whitespace> <Identifiers> <Whitespace> ? '=' <Whitespace> ? <Type> <Endline>
    struct TypealiasField:Parseable, CustomStringConvertible
    {
        struct Typealias:Parseable.Terminal 
        {
            static 
            let token:String = "typealias"
        }
        
        let identifiers:[String]
        let target:Symbol.SwiftType
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Typealias                     = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace             = try .parse(tokens, position: &position), 
                identifiers:Symbol.Identifiers  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                _:Token.Equals                  = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                target:Symbol.SwiftType         = try .parse(tokens, position: &position), 
                _:Symbol.Endline                = try .parse(tokens, position: &position)
            return .init(identifiers: identifiers.identifiers, target: target)
        }
        
        var description:String 
        {
            """
            TypealiasField 
            {
                identifiers : \(self.identifiers)
                target      : \(self.target)
            }
            """
        }
    }
    
    // ConformanceField    ::= ':' <Whitespace> ? <ProtocolCompositionType> ( <Whitespace> <WhereClauses> ) ? <Endline>
    struct ConformanceField:Parseable, CustomStringConvertible
    {
        let conformances:[[String]]
        let conditions:[WhereClause]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Colon               = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                conformances:Symbol.ProtocolCompositionType = try .parse(tokens, position: &position), 
                conditions:List<Symbol.Whitespace, Symbol.WhereClauses>? = 
                                                  .parse(tokens, position: &position),
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            return .init(conformances: conformances.protocols, conditions: conditions?.body.clauses ?? [])
        }
        
        var description:String 
        {
            """
            ConformanceField 
            {
                conformances  : \(self.conformances)
                conditions    : \(self.conditions)
            }
            """
        }
    }
    
    //  ImplementationField ::= '?:' <Whitespace> ? <Identifiers> ( <Whitespace> <WhereClauses> ) ? <Endline>
    struct ImplementationField:Parseable 
    {
        let conformance:[String]
        let conditions:[WhereClause]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:List<Token.Question, Token.Colon> = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?                =     .parse(tokens, position: &position), 
                conformance:Symbol.Identifiers      = try .parse(tokens, position: &position), 
                conditions:List<Symbol.Whitespace, Symbol.WhereClauses>? = 
                                                          .parse(tokens, position: &position), 
                _:Symbol.Endline                    = try .parse(tokens, position: &position)
            return .init(conformance: conformance.identifiers, conditions: conditions?.body.clauses ?? [])
        }
    }
    
    //  ConstraintsField    ::= <WhereClauses> <Endline>
    //  WhereClauses        ::= 'where' <Whitespace> <WhereClause> ( <Whitespace> ? ',' <Whitespace> ? <WhereClause> ) * 
    //  WhereClause         ::= <Identifiers> <Whitespace> ? <WherePredicate>
    //  WherePredicate      ::= ':' <Whitespace> ? <ProtocolCompositionType> 
    //                        | '==' <Whitespace> ? <Type>
    struct ConstraintsField:Parseable, CustomStringConvertible
    {
        let clauses:[WhereClause]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let clauses:Symbol.WhereClauses = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            return .init(clauses: clauses.clauses)
        }
        
        var description:String 
        {
            """
            ConstraintsField 
            {
                constraint  : \(self.clauses.map(\.description).joined(separator: ", "))
            }
            """
        }
    }
    struct WhereClauses:Parseable 
    {
        struct Where:Parseable.Terminal 
        {
            static 
            let token:String = "where"
        }
        
        let clauses:[WhereClause]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Where                 = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace     = try .parse(tokens, position: &position), 
                head:Symbol.WhereClause = try .parse(tokens, position: &position),
                body:[List<Symbol.Whitespace?, List<Token.Comma, List<Symbol.Whitespace?, Symbol.WhereClause>>>] = 
                                              .parse(tokens, position: &position)
            return .init(clauses: [head] + body.map(\.body.body.body))
        }
    }
    struct WhereClause:Parseable, CustomStringConvertible
    {
        let subject:[String], 
            predicate:WherePredicate 
            
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let subject:Symbol.Identifiers      = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?            =     .parse(tokens, position: &position), 
                predicate:Symbol.WherePredicate = try .parse(tokens, position: &position)
            return .init(subject: subject.identifiers, predicate: predicate)
        }
        
        var description:String 
        {
            switch self.predicate  
            {
            case .conforms(let protocols):
                return "\(self.subject.joined(separator: ".")):\(protocols.map{ $0.joined(separator: ".") }.joined(separator: " & "))"
            case .equals(let type):
                return "\(self.subject.joined(separator: ".")) == \(type)"
            }
        }
    }
    enum WherePredicate:Parseable
    {
        case conforms([[String]]) 
        case equals(Symbol.SwiftType) 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:List<Token.Colon, Symbol.Whitespace?> = 
                .parse(tokens, position: &position), 
                    let protocols:Symbol.ProtocolCompositionType = 
                .parse(tokens, position: &position)
            {
                return .conforms(protocols.protocols)
            }
            else if let _:List<Token.EqualsEquals, Symbol.Whitespace?> = 
                .parse(tokens, position: &position), 
                    let type:Symbol.SwiftType = 
                .parse(tokens, position: &position)
            {
                return .equals(type)
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    //  AttributeField      ::= '@' <Whitespace> ? <DeclarationAttribute> <Endline>
    //  DeclarationAttribute::= 'frozen'
    //                        | 'inlinable'
    //                        | 'propertyWrapper'
    //                        | 'specialized' <Whitespace> <WhereClauses>
    //                        | ':'  <Whitespace> ? <Type>
    enum AttributeField:Parseable
    {
        struct Frozen:Parseable.Terminal 
        {
            static 
            let token:String = "frozen"
        }
        struct Inlinable:Parseable.Terminal 
        {
            static 
            let token:String = "inlinable"
        }
        struct PropertyWrapper:Parseable.Terminal 
        {
            static 
            let token:String = "propertyWrapper"
        }
        struct Specialized:Parseable.Terminal 
        {
            static 
            let token:String = "specialized"
        }
        
        case frozen 
        case inlinable 
        case wrapper
        case specialized(Symbol.WhereClauses)
        case wrapped(Symbol.SwiftType)
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.At              = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position)
            
            if      let _:List<Frozen, Symbol.Endline> = .parse(tokens, position: &position)
            {
                return .frozen
            }
            else if let _:List<Inlinable, Symbol.Endline> = .parse(tokens, position: &position)
            {
                return .inlinable 
            }
            else if let _:List<PropertyWrapper, Symbol.Endline> = 
                .parse(tokens, position: &position)
            {
                return .wrapper 
            }
            else if let specialized:List<Specialized, List<Symbol.Whitespace, List<Symbol.WhereClauses, Symbol.Endline>>> = 
                .parse(tokens, position: &position)
            {
                return .specialized(specialized.body.body.head)
            }
            else if let wrapped:List<Token.Colon, List<Symbol.Whitespace?, List<Symbol.SwiftType, Symbol.Endline>>> = 
                .parse(tokens, position: &position)
            {
                return .wrapped(wrapped.body.body.head) 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // ParameterField      ::= '-' <Whitespace> ? <ParameterName> <Whitespace> ? ':' <Whitespace> ? <FunctionParameter> <Endline>
    // ParameterName       ::= <Identifier> 
    //                       | '->'
    struct ParameterField:Parseable, CustomStringConvertible
    {
        let name:Symbol.ParameterName 
        let parameter:Symbol.FunctionParameter 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hyphen              = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                name:Symbol.ParameterName   = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Colon               = try .parse(tokens, position: &position),
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                parameter:Symbol.FunctionParameter = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            return .init(name: name, parameter: parameter)
        }
        
        var description:String 
        {
            """
            ParameterField 
            {
                name        : \(self.name)
                parameter   : \(self.parameter)
            }
            """
        }
    }
    enum ParameterName:Parseable
    {
        case parameter(String) 
        case `return`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let identifier:Symbol.Identifier = .parse(tokens, position: &position)
            {
                return .parameter(identifier.string)
            }
            else if let _:Token.Arrow = .parse(tokens, position: &position)
            {
                return .return
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // ThrowsField         ::= 'throws' <Endline>
    //                       | 'rethrows' <Endline>
    enum ThrowsField:Parseable 
    {
        case `throws` 
        case `rethrows`
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:List<Token.Throws, Symbol.Endline> = .parse(tokens, position: &position)
            {
                return .throws
            }
            else if let _:List<Token.Rethrows, Symbol.Endline> = .parse(tokens, position: &position)
            {
                return .rethrows
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
    
    // RequirementField    ::= 'required' <Endline>
    //                       | 'defaulted' ( <Whitespace> <WhereClauses> ) ? <Endline>
    enum RequirementField:Parseable 
    {
        struct Required:Parseable.Terminal 
        {
            static 
            let token:String = "required"
        }
        struct Defaulted:Parseable.Terminal 
        {
            static 
            let token:String = "defaulted"
        }
        
        case required
        case defaulted([WhereClause])
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let _:List<Required, Symbol.Endline> = .parse(tokens, position: &position)
            {
                return .required
            }
            else if let _:Defaulted = .parse(tokens, position: &position)
            {
                let conditions:List<Symbol.Whitespace, WhereClauses>? = 
                    .parse(tokens, position: &position) 
                if let _:Symbol.Endline = .parse(tokens, position: &position) 
                {
                    return .defaulted(conditions?.body.clauses ?? [])
                }
            }
            
            throw ParsingError.unexpected(tokens, position, expected: Self.self)
        }
    }
    
    // TopicKey            ::= [a-zA-Z0-9\-] *
    // TopicField          ::= '#' <Whitespace>? '[' <BalancedContent> * ']' <Whitespace>? '(' <Whitespace> ? <TopicKey> ( <Whitespace> ? ',' <Whitespace> ? <TopicKey> ) * <Whitespace> ? ')' <Endline>
    // TopicElementField   ::= '##' <Whitespace>? '(' <Whitespace> ? ( <ASCIIDigit> * <Whitespace> ? ':' <Whitespace> ? ) ? <TopicKey> <Whitespace> ? ')' <Endline>
    struct TopicField:Parseable 
    {
        let display:String, 
            keys:[String] 
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hashtag             = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Bracket.Left        = try .parse(tokens, position: &position), 
                display:[Token.BalancedContent] = .parse(tokens, position: &position), 
                _:Token.Bracket.Right       = try .parse(tokens, position: &position), 
                _:Token.Parenthesis.Left    = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                head:[Token.Alphanumeric]   =     .parse(tokens, position: &position), 
                body:[List<Symbol.Whitespace?, List<Token.Comma, List<Symbol.Whitespace?, [Token.Alphanumeric]>>>] =     
                                                  .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right   = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position) 
            let keys:[String] = [.init(head.map(\.character))] 
            + 
            body.map(\.body.body.body).map{ .init($0.map(\.character)) }
            return .init(display: .init(display.map(\.character)), keys: keys)
        }
    }
    struct TopicElementField:Parseable
    {
        let key:String?
        let rank:Int
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Hashtag             = try .parse(tokens, position: &position), 
                _:Token.Hashtag             = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Parenthesis.Left    = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                rank:List<[Token.ASCIIDigit], List<Symbol.Whitespace?, List<Token.Colon, Symbol.Whitespace?>>>? = 
                                                  .parse(tokens, position: &position),
                key:[Token.Alphanumeric]    =     .parse(tokens, position: &position), 
                _:Symbol.Whitespace?        =     .parse(tokens, position: &position), 
                _:Token.Parenthesis.Right   = try .parse(tokens, position: &position), 
                _:Symbol.Endline            = try .parse(tokens, position: &position)
            let r:Int = Int.init(String.init(rank?.head.map(\.character) ?? [])) ?? Int.max
            return .init(key: key.isEmpty ? nil : .init(key.map(\.character)), rank: r)
        }
    }
    
    // ParagraphField      ::= <ParagraphLine> <ParagraphLine> *
    // ParagraphLine       ::= '    ' ' ' * [^\s] . * '\n'
    struct ParagraphField:Parseable, CustomStringConvertible
    {
        let elements:[Markdown.Element]
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let head:Symbol.ParagraphLine   = try .parse(tokens, position: &position), 
                body:[Symbol.ParagraphLine] =     .parse(tokens, position: &position)
            
            var characters:[Character] = []
            for line:Symbol.ParagraphLine in [head] + body 
            {
                let trimmed:String = 
                {
                    var substring:Substring = line.string[...] 
                    while substring.last?.isWhitespace == true 
                    {
                        substring.removeLast()
                    }
                    return .init(substring)
                }()
                characters.append(contentsOf: trimmed)
                characters.append(" ")
            }
            var c:Int = characters.startIndex
            let elements:[Markdown.Element] = .parse(characters, position: &c)
            return .init(elements: elements)
        }
        
        var description:String 
        {
            "\(self.elements)"
        }
    }
    struct ParagraphLine:Parseable 
    {
        let string:String
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            let _:Token.Space           = try .parse(tokens, position: &position), 
                _:Token.Space           = try .parse(tokens, position: &position), 
                _:Token.Space           = try .parse(tokens, position: &position), 
                _:Token.Space           = try .parse(tokens, position: &position), 
                _:Symbol.Whitespace?    =     .parse(tokens, position: &position), 
                head:Token.Darkspace    = try .parse(tokens, position: &position), 
                body:[Token.Wildcard]   =     .parse(tokens, position: &position), 
                _:Token.Newline         = try .parse(tokens, position: &position)
            return .init(string: .init([head.character] + body.map(\.character)))
        }
    }
    
    // Field               ::= <ModuleField>
    //                       | <FunctionField>
    //                       | <SubscriptField>
    //                       | <MemberField>
    //                       | <TypeField>
    //                       | <TypealiasField>
    //                       | <AnnotationField>
    //                       | <AttributeField>
    //                       | <ConstraintsField>
    //                       | <ThrowsField>
    //                       | <RequirementField>
    //                       | <ParameterField>
    //                       | <TopicField>
    //                       | <TopicElementField>
    //                       | <ParagraphField>
    //                       | <Separator>
    // Separator           ::= <Endline>
    enum Field:Parseable 
    {
        case module(Symbol.ModuleField) 
        
        case `subscript`(Symbol.SubscriptField) 
        case function(Symbol.FunctionField) 
        case member(Symbol.MemberField) 
        case type(Symbol.TypeField) 
        case `typealias`(Symbol.TypealiasField) 
        
        case implementation(Symbol.ImplementationField) 
        case conformance(Symbol.ConformanceField) 
        case constraints(Symbol.ConstraintsField) 
        case attribute(Symbol.AttributeField) 
        case `throws`(Symbol.ThrowsField) 
        case requirement(Symbol.RequirementField) 
        case parameter(Symbol.ParameterField) 
        
        case topic(Symbol.TopicField)
        case topicElement(Symbol.TopicElementField)
        
        case paragraph(Symbol.ParagraphField) 
        case separator
        
        static 
        func parse(_ tokens:[Character], position:inout Int) throws -> Self
        {
            if      let field:Symbol.ModuleField = .parse(tokens, position: &position)
            {
                return .module(field)
            }
            if      let field:Symbol.FunctionField = .parse(tokens, position: &position)
            {
                return .function(field)
            }
            else if let field:Symbol.SubscriptField = .parse(tokens, position: &position)
            {
                return .subscript(field)
            }
            else if let field:Symbol.MemberField = .parse(tokens, position: &position)
            {
                return .member(field)
            }
            else if let field:Symbol.TypeField = .parse(tokens, position: &position)
            {
                return .type(field)
            }
            else if let field:Symbol.TypealiasField = .parse(tokens, position: &position)
            {
                return .typealias(field)
            }
            else if let field:Symbol.ImplementationField = .parse(tokens, position: &position)
            {
                return .implementation(field)
            }
            else if let field:Symbol.ConformanceField = .parse(tokens, position: &position)
            {
                return .conformance(field)
            }
            else if let field:Symbol.ConstraintsField = .parse(tokens, position: &position)
            {
                return .constraints(field)
            }
            else if let field:Symbol.AttributeField = .parse(tokens, position: &position)
            {
                return .attribute(field)
            }
            else if let field:Symbol.ThrowsField = .parse(tokens, position: &position)
            {
                return .throws(field)
            }
            else if let field:Symbol.RequirementField = .parse(tokens, position: &position)
            {
                return .requirement(field)
            }
            else if let field:Symbol.ParameterField = .parse(tokens, position: &position)
            {
                return .parameter(field)
            }
            else if let field:Symbol.TopicField = .parse(tokens, position: &position)
            {
                return .topic(field)
            }
            else if let field:Symbol.TopicElementField = .parse(tokens, position: &position)
            {
                return .topicElement(field)
            }
            else if let field:Symbol.ParagraphField = .parse(tokens, position: &position)
            {
                return .paragraph(field)
            }
            else if let _:Symbol.Endline = .parse(tokens, position: &position)
            {
                return .separator 
            }
            else 
            {
                throw ParsingError.unexpected(tokens, position, expected: Self.self)
            }
        }
    }
} */
