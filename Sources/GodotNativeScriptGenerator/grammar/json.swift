enum JSON:Grammar.Parsable
{
    enum Whitespace
    {
        struct Character:Grammar.Parsable.CharacterClass 
        {
            init?(_ character:Swift.Character)
            {
                switch character 
                {
                case " ", "\t", "\n", "\r":
                    return 
                default:
                    return nil
                }
            }
        }
    }
    
    enum Value:Grammar.Parsable
    {
        case null 
        case bool(Bool)
        case int(Int64)
        case double(Double)
        case string(Swift.String)
        case array([Self])
        case object([Swift.String: Self])
        
        struct Null:Grammar.Parsable.Terminal 
        {
            static 
            let token:Swift.String = "null"
        }
        struct True:Grammar.Parsable.Terminal 
        {
            static 
            let token:Swift.String = "true"
        }
        struct False:Grammar.Parsable.Terminal 
        {
            static 
            let token:Swift.String = "false"
        }
        
        init(parsing input:inout Grammar.Input) throws 
        {
            let start:Swift.String.Index    = input.index 
            if      let _:Null              = .init(parsing: &input)
            {
                self = .null 
            }
            else if let _:True              = .init(parsing: &input)
            {
                self = .bool(true)
            }
            else if let _:False             = .init(parsing: &input)
            {
                self = .bool(false)
            }
            else if let number:Number       = .init(parsing: &input)
            {
                switch number 
                {
                case .int(let int):
                    self = .int(int)
                case .double(let double):
                    self = .double(double)
                }
            }
            else if let string:JSON.String  = .init(parsing: &input)
            {
                self = .string(string.string)
            }
            else if let array:JSON.Array    = .init(parsing: &input)
            {
                self = .array(array.elements)
            }
            else if let object:JSON.Object  = .init(parsing: &input)
            {
                self = .object(object.items)
            }
            else 
            {
                throw input.expected(Self.self, from: start)
            }
        }
    }
    
    enum Number:Grammar.Parsable 
    {
        struct Minus:Grammar.Parsable.Terminal 
        {
            static 
            let token:Swift.String = "-"
        }
        struct PlusOrMinus:Grammar.Parsable.CharacterClass 
        {
            let character:Character 
            init?(_ character:Character)
            {
                switch character 
                {
                case "+", "-":
                    self.character = character 
                default:
                    return nil
                }
            }
        }
        struct Point:Grammar.Parsable.Terminal 
        {
            static 
            let token:Swift.String = "."
        }
        struct E:Grammar.Parsable.CharacterClass 
        {
            init?(_ character:Character)
            {
                switch character 
                {
                case "e", "E":
                    return 
                default:
                    return nil
                }
            }
        }
        struct DecimalDigit:Grammar.Parsable.CharacterClass 
        {
            let value:Int64 
            init?(_ character:Character)
            {
                switch character 
                {
                case "0":   self.value = 0
                case "1":   self.value = 1
                case "2":   self.value = 2
                case "3":   self.value = 3
                case "4":   self.value = 4
                case "5":   self.value = 5
                case "6":   self.value = 6
                case "7":   self.value = 7
                case "8":   self.value = 8
                case "9":   self.value = 9
                default:    return nil
                }
            }
        }
        struct DecimalDigits:Grammar.Parsable 
        {
            let value:Int64 
            
            init(parsing input:inout Grammar.Input) throws
            {
                let digits:List<DecimalDigit, [DecimalDigit]> = try .init(parsing: &input)
                var value:Int64 = 0 
                for digit:Int64 in [digits.head.value] + digits.body.map(\.value)
                {
                    value *= 10 
                    value += digit
                }
                self.value = value
            }
        }
        
        case int(Int64)
        case double(Double)
        
        init(parsing input:inout Grammar.Input) throws
        {
            let minus:Minus?                                            =     .init(parsing: &input), 
                integer:DecimalDigits                                   = try .init(parsing: &input), 
                fraction:List<Point, DecimalDigits>?                    =     .init(parsing: &input), 
                exponent:List<E, List<PlusOrMinus?, DecimalDigits>>?    =     .init(parsing: &input)
            
            if fraction == nil, exponent == nil 
            {
                if let _:Minus = minus 
                {
                    self = .int(-integer.value)
                }
                else 
                {
                    self = .int(integer.value)
                }
            }
            else 
            {
                let source:Swift.String =
                """
                \(minus == nil ? "" : "-")\
                \(integer.value)\
                \(fraction.map{ ".\($0.body.value)" } ?? "")\
                \(exponent.map{ "e\( $0.body.head?.character ?? "+" )\($0.body.body.value)" } ?? "")
                """
                guard let double:Double = .init(source)
                else 
                {
                    fatalError("unreachable (could not parse pre-validated floating point literal)")
                }
                self = .double(double)
            }
        }
    }
    struct String:Grammar.Parsable 
    {
        struct Quote:Grammar.Parsable.Terminal 
        {
            static 
            let token:Swift.String = "\""
        }
        struct Element:Grammar.Parsable 
        {
            struct Escaped:Grammar.Parsable 
            {
                struct Backslash:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "\\"
                }
                struct Slash:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "/"
                }
                struct B:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "b"
                }
                struct F:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "f"
                }
                struct N:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "n"
                }
                struct R:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "r"
                }
                struct T:Grammar.Parsable.Terminal 
                {
                    static 
                    let token:Swift.String = "t"
                }
                struct HexDigit:Grammar.Parsable.CharacterClass 
                {
                    let value:Int
                    init?(_ character:Character)
                    {
                        guard let value:Int = character.hexDigitValue 
                        else 
                        {
                            return nil 
                        }
                        self.value = value 
                    }
                }
                
                let character:Swift.Character
                
                init(parsing input:inout Grammar.Input) throws
                {
                    let start:Swift.String.Index  = input.index 
                    let _:Backslash         = try .init(parsing: &input)
                    // must come first, or it is ambiguous with '\f'
                    if      let hex:List<HexDigit, 
                                    List<HexDigit, 
                                    List<HexDigit, HexDigit>>> = .init(parsing: &input)
                    {
                        let value:Int   = hex.head.value            << 12 
                                        | hex.body.head.value       << 8
                                        | hex.body.body.head.value  << 4
                                        | hex.body.body.body.value 
                        guard let scalar:Unicode.Scalar = .init(value)
                        else 
                        {
                            throw input.expected(Self.self, from: start)
                        }
                        self.character  = .init(scalar)
                    }
                    else if let _:Quote     =     .init(parsing: &input)
                    {
                        self.character = "\""
                    }
                    else if let _:Backslash =     .init(parsing: &input)
                    {
                        self.character = "\\"
                    }
                    else if let _:Slash     =     .init(parsing: &input)
                    {
                        self.character = "/"
                    }
                    else if let _:B         =     .init(parsing: &input)
                    {
                        self.character = "\u{08}"
                    }
                    else if let _:F         =     .init(parsing: &input)
                    {
                        self.character = "\u{0C}"
                    }
                    else if let _:N         =     .init(parsing: &input)
                    {
                        self.character = "\u{0A}"
                    }
                    else if let _:R         =     .init(parsing: &input)
                    {
                        self.character = "\u{0D}"
                    }
                    else if let _:T         =     .init(parsing: &input)
                    {
                        self.character = "\u{09}"
                    }
                    else 
                    {
                        throw input.expected(Self.self, from: start)
                    }
                }
            }
            struct Unescaped:Grammar.Parsable.CharacterClass
            {
                let character:Swift.Character 
                
                init?(_ character:Swift.Character)
                {
                    for scalar:Unicode.Scalar in character.unicodeScalars
                    {
                        switch scalar 
                        {
                        case "\u{20}" ... "\u{21}", "\u{23}" ... "\u{5B}", "\u{5D}" ... "\u{10FFFF}":
                            break  
                        default:
                            return nil
                        }
                    }
                    self.character = character
                }
            } 
            
            let character:Character 
            
            init(parsing input:inout Grammar.Input) throws
            {
                if let unescaped:Unescaped  =     .init(parsing: &input)
                {
                    self.character = unescaped.character
                }
                else 
                {
                    let escaped:Escaped     = try .init(parsing: &input)
                    self.character = escaped.character
                }
            }
        }
        
        let string:Swift.String 
        
        init(parsing input:inout Grammar.Input) throws
        {
            let _:Quote             = try .init(parsing: &input), 
                elements:[Element]  =     .init(parsing: &input), 
                _:Quote             = try .init(parsing: &input)
            self.string = .init(elements.map(\.character))
        }
    }
    enum Separator 
    {
        struct Name:Grammar.Parsable 
        {
            init(parsing input:inout Grammar.Input) throws
            {
                let _:[Whitespace.Character]    =     .init(parsing: &input),
                    _:Grammar.Token.Colon       = try .init(parsing: &input), 
                    _:[Whitespace.Character]    =     .init(parsing: &input)
            }
        }
        struct Value:Grammar.Parsable 
        {
            init(parsing input:inout Grammar.Input) throws
            {
                let _:[Whitespace.Character]    =     .init(parsing: &input),
                    _:Grammar.Token.Comma       = try .init(parsing: &input), 
                    _:[Whitespace.Character]    =     .init(parsing: &input)
            }
        }
    }
    struct Array:Grammar.Parsable 
    {
        struct Start:Grammar.Parsable 
        {
            init(parsing input:inout Grammar.Input) throws
            {
                let _:[Whitespace.Character]        =     .init(parsing: &input),
                    _:Grammar.Token.Bracket.Left    = try .init(parsing: &input), 
                    _:[Whitespace.Character]        =     .init(parsing: &input)
            }
        }
        struct End:Grammar.Parsable 
        {
            init(parsing input:inout Grammar.Input) throws
            {
                let _:[Whitespace.Character]        =     .init(parsing: &input),
                    _:Grammar.Token.Bracket.Right   = try .init(parsing: &input), 
                    _:[Whitespace.Character]        =     .init(parsing: &input)
            }
        }
        
        let elements:[Value]
        
        init(parsing input:inout Grammar.Input) throws 
        {
            let _:Start         = try .init(parsing: &input)
            if let head:Value   =     .init(parsing: &input)
            {
                let body:[List<Separator.Value, Value>] = .init(parsing: &input)
                self.elements = [head] + body.map(\.body)
            }
            else 
            {
                self.elements = []
            }
            let _:End           = try .init(parsing: &input) 
        }
    }
    struct Object:Grammar.Parsable 
    {
        struct Start:Grammar.Parsable 
        {
            init(parsing input:inout Grammar.Input) throws
            {
                let _:[Whitespace.Character]    =     .init(parsing: &input),
                    _:Grammar.Token.Brace.Left  = try .init(parsing: &input), 
                    _:[Whitespace.Character]    =     .init(parsing: &input)
            }
        }
        struct End:Grammar.Parsable 
        {
            init(parsing input:inout Grammar.Input) throws
            {
                let _:[Whitespace.Character]    =     .init(parsing: &input),
                    _:Grammar.Token.Brace.Right = try .init(parsing: &input), 
                    _:[Whitespace.Character]    =     .init(parsing: &input)
            }
        }
        struct Item:Grammar.Parsable 
        {
            let key:Swift.String 
            let value:Value 
            
            init(parsing input:inout Grammar.Input) throws
            {
                let key:JSON.String     = try .init(parsing: &input),
                    _:Separator.Name    = try .init(parsing: &input), 
                    value:Value         = try .init(parsing: &input)
                self.key    = key.string 
                self.value  = value 
            }
        }
        
        let items:[Swift.String: Value]
        
        init(parsing input:inout Grammar.Input) throws 
        {
            let _:Start         = try .init(parsing: &input)
            if let head:Item    =     .init(parsing: &input)
            {
                let body:[List<Separator.Value, Item>]  = .init(parsing: &input)
                var items:[Swift.String: Value]         = [head.key: head.value]
                for item:Item in body.map(\.body)
                {
                    items[item.key] = item.value 
                }
                self.items = items 
            }
            else 
            {
                self.items = [:]
            }
            let _:End           = try .init(parsing: &input) 
        }
    }
    
    case array([Value])
    case object([Swift.String: Value])
    
    init(parsing input:inout Grammar.Input) throws 
    {
        let start:Swift.String.Index    = input.index 
        if      let array:JSON.Array    = .init(parsing: &input)
        {
            self = .array(array.elements)
        }
        else if let object:JSON.Object  = .init(parsing: &input)
        {
            self = .object(object.items)
        }
        else 
        {
            throw input.expected(Self.self, from: start)
        }
    }
}

extension JSON 
{
    struct Decoder
    {
        enum Error:Swift.Error 
        {
            case invalidIndex(Int,          path:[CodingKey])
            case invalidKey(Swift.String,   path:[CodingKey])
            case expectedUnkeyedContainer
            case expectedKeyedContainer
            
            case cannotConvert
        }
        
        let codingPath:[CodingKey]
        let userInfo:[CodingUserInfoKey: Any]
        
        let value:JSON.Value
        
        init(_ value:JSON.Value, path:[CodingKey]) 
        {
            self.value      = value
            self.codingPath = path
            self.userInfo   = [:]
        }
        init(json:JSON) 
        {
            switch json 
            {
            case .array(let elements):
                self.init(.array(elements), path: [])
            case .object(let items):
                self.init(.object(items),   path: [])
            }
        }
    }
}
extension JSON.Array 
{
    struct Index:CodingKey 
    {
        private 
        let value:Int
        var intValue:Int? 
        {
            self.value 
        }
        var stringValue:String
        {
            "\(self.value)"
        }
        
        init(intValue:Int)
        {
            self.value = intValue
        }
        init?(stringValue:String)
        {
            guard let value:Int = .init(stringValue)
            else 
            {
                return nil 
            }
            self.value = value
        }
    }
}
extension JSON.Value
{
    func decodeNil() -> Bool
    {
        guard case .null = self 
        else 
        {
            return false 
        }
        return true
    }
    func decode(_:Bool.Type) throws -> Bool
    {
        guard case .bool(let value) = self 
        else 
        {
            throw JSON.Decoder.Error.cannotConvert
        }
        return value
    }
    func decode<T>(_:T.Type) throws -> T 
        where T:FixedWidthInteger & SignedInteger
    {
        switch self 
        {
        case .int(let value):
            guard let integer:T = .init(exactly: value)
            else 
            {
                fallthrough 
            }
            return integer 
        default:
            throw JSON.Decoder.Error.cannotConvert
        }
    }
    func decode<T>(_:T.Type) throws -> T 
        where T:FixedWidthInteger & UnsignedInteger
    {
        switch self 
        {
        case .int(let value):
            guard let integer:T = .init(exactly: UInt64.init(bitPattern: value))
            else 
            {
                fallthrough 
            }
            return integer 
        default:
            throw JSON.Decoder.Error.cannotConvert
        }
    }
    func decode<T>(_:T.Type) throws -> T 
        where T:BinaryFloatingPoint
    {
        switch self 
        {
        case .int(let value):       return .init(value)
        case .double(let value):    return .init(value)
        default:                    throw JSON.Decoder.Error.cannotConvert
        }
    }
    func decode(_:String.Type) throws -> String
    {
        switch self 
        {
        case .int(let value):       return "\(value)"
        case .double(let value):    return "\(value)"
        case .string(let value):    return    value
        default:                    throw  JSON.Decoder.Error.cannotConvert
        }
    }
    func decode<T>(_:T.Type, path:[CodingKey]) throws -> T 
        where T:Decodable
    {
        try .init(from: JSON.Decoder.init(self, path: path))
    }
    
    func decodeContainer<Key>(keyedBy _:Key.Type, path:[CodingKey]) throws 
        -> JSON.Decoder.KeyedContainer<Key>
        where Key:CodingKey 
    {
        guard case .object(let dictionary) = self 
        else 
        {
            throw JSON.Decoder.Error.expectedKeyedContainer
        }
        return .init(dictionary: dictionary, path: path)
    }
    func decodeContainer(keyedBy _:Void.Type, path:[CodingKey]) throws 
        -> JSON.Decoder.UnkeyedContainer
    {
        guard case .array(let array) = self 
        else 
        {
            throw JSON.Decoder.Error.expectedUnkeyedContainer
        }
        return .init(array: array, path: path)
    }
}
extension JSON.Decoder:Decoder & SingleValueDecodingContainer
{
    struct KeyedContainer<Key>:KeyedDecodingContainerProtocol
        where Key:CodingKey
    {
        let codingPath:[CodingKey]
        let allKeys:[Key]
        let dictionary:[String: JSON.Value]
        
        init(dictionary:[String: JSON.Value], path:[CodingKey])
        {
            self.codingPath = path
            self.allKeys    = dictionary.keys.compactMap(Key.init(stringValue:))
            self.dictionary = dictionary 
        }
        
        func contains(_ key:Key) -> Bool 
        {
            self.dictionary.index(forKey: key.stringValue) != nil
        }
        
        private 
        func value(_ key:Key) throws -> JSON.Value 
        {
            guard let child:JSON.Value = self.dictionary[key.stringValue]
            else 
            {
                throw Error.invalidKey(key.stringValue, path: self.codingPath)
            }
            return child
        }
        
        func decodeNil(forKey key:Key) -> Bool
        {
            self.dictionary[key.stringValue]?.decodeNil() ?? true
        }
        func decode(_:Bool.Type, forKey key:Key) throws -> Bool
        {
            try self.value(key).decode(Bool.self)
        }
        func decode(_:Int.Type, forKey key:Key) throws -> Int
        {
            try self.value(key).decode(Int.self)
        }
        func decode(_:Int64.Type, forKey key:Key) throws -> Int64
        {
            try self.value(key).decode(Int64.self)
        }
        func decode(_:Int32.Type, forKey key:Key) throws -> Int32
        {
            try self.value(key).decode(Int32.self)
        }
        func decode(_:Int16.Type, forKey key:Key) throws -> Int16
        {
            try self.value(key).decode(Int16.self)
        }
        func decode(_:Int8.Type, forKey key:Key) throws -> Int8
        {
            try self.value(key).decode(Int8.self)
        }
        func decode(_:UInt.Type, forKey key:Key) throws -> UInt
        {
            try self.value(key).decode(UInt.self)
        }
        func decode(_:UInt64.Type, forKey key:Key) throws -> UInt64
        {
            try self.value(key).decode(UInt64.self)
        }
        func decode(_:UInt32.Type, forKey key:Key) throws -> UInt32
        {
            try self.value(key).decode(UInt32.self)
        }
        func decode(_:UInt16.Type, forKey key:Key) throws -> UInt16
        {
            try self.value(key).decode(UInt16.self)
        }
        func decode(_:UInt8.Type, forKey key:Key) throws -> UInt8
        {
            try self.value(key).decode(UInt8.self)
        }
        func decode(_:Float.Type, forKey key:Key) throws -> Float
        {
            try self.value(key).decode(Float.self)
        }
        func decode(_:Double.Type, forKey key:Key) throws -> Double
        {
            try self.value(key).decode(Double.self)
        }
        func decode(_:String.Type, forKey key:Key) throws -> String
        {
            try self.value(key).decode(String.self)
        }
        func decode<T>(_:T.Type, forKey key:Key) throws -> T 
            where T:Decodable
        {
            try self.value(key).decode(T.self, path: self.codingPath + [key])
        }
        
        func nestedContainer<NestedKey>(keyedBy _:NestedKey.Type, forKey key:Key) throws 
            -> KeyedDecodingContainer<NestedKey>
        {
            .init(try self.value(key).decodeContainer(keyedBy: NestedKey.self, 
                path: self.codingPath + [key]))
        }
        func nestedUnkeyedContainer(forKey key:Key) throws 
            -> UnkeyedDecodingContainer
        {
            try self.value(key).decodeContainer(keyedBy: Void.self, 
                path: self.codingPath + [key])
        }
        
        func superDecoder() -> Decoder
        {
            fatalError("unimplemented")
        }
        func superDecoder(forKey key:Key) -> Decoder
        {
            fatalError("unimplemented")
        }
    }
    struct UnkeyedContainer:UnkeyedDecodingContainer
    {
        let codingPath:[CodingKey]
        
        private 
        let array:[JSON.Value]
        private(set)
        var currentIndex:Int 
        
        var count:Int?
        {
            self.array.count
        }
        var isAtEnd:Bool 
        {
            self.currentIndex >= self.array.endIndex
        }
        
        init(array:[JSON.Value], path:[CodingKey])
        {
            self.codingPath     = path
            self.currentIndex   = array.startIndex 
            self.array          = array 
        }
        
        private mutating 
        func next() throws -> JSON.Value 
        {
            if self.isAtEnd 
            {
                throw Error.invalidIndex(self.currentIndex, path: self.codingPath)
            }
            defer 
            {
                self.currentIndex += 1
            }
            return self.array[self.currentIndex]
        }
        
        mutating 
        func decodeNil() throws -> Bool
        {
            if self.isAtEnd 
            {
                throw Error.invalidIndex(self.currentIndex, path: self.codingPath)
            }
            if self.array[self.currentIndex].decodeNil()
            {
                self.currentIndex += 1
                return true 
            }
            else 
            {
                return false 
            }
        }
        mutating 
        func decode(_:Bool.Type) throws -> Bool
        {
            try self.next().decode(Bool.self)
        }
        mutating 
        func decode(_:Int.Type) throws -> Int
        {
            try self.next().decode(Int.self)
        }
        mutating 
        func decode(_:Int64.Type) throws -> Int64
        {
            try self.next().decode(Int64.self)
        }
        mutating 
        func decode(_:Int32.Type) throws -> Int32
        {
            try self.next().decode(Int32.self)
        }
        mutating 
        func decode(_:Int16.Type) throws -> Int16
        {
            try self.next().decode(Int16.self)
        }
        mutating 
        func decode(_:Int8.Type) throws -> Int8
        {
            try self.next().decode(Int8.self)
        }
        mutating 
        func decode(_:UInt.Type) throws -> UInt
        {
            try self.next().decode(UInt.self)
        }
        mutating 
        func decode(_:UInt64.Type) throws -> UInt64
        {
            try self.next().decode(UInt64.self)
        }
        mutating 
        func decode(_:UInt32.Type) throws -> UInt32
        {
            try self.next().decode(UInt32.self)
        }
        mutating 
        func decode(_:UInt16.Type) throws -> UInt16
        {
            try self.next().decode(UInt16.self)
        }
        mutating 
        func decode(_:UInt8.Type) throws -> UInt8
        {
            try self.next().decode(UInt8.self)
        }
        mutating 
        func decode(_:Float.Type) throws -> Float
        {
            try self.next().decode(Float.self)
        }
        mutating 
        func decode(_:Double.Type) throws -> Double
        {
            try self.next().decode(Double.self)
        }
        mutating 
        func decode(_:String.Type) throws -> String
        {
            try self.next().decode(String.self)
        }
        
        private 
        var nextPath:[CodingKey]
        {
            self.codingPath + [JSON.Array.Index.init(intValue: self.currentIndex)]
        }
        
        mutating 
        func decode<T>(_:T.Type) throws -> T 
            where T:Decodable
        {
            let path:[CodingKey] = self.nextPath
            return try self.next().decode(T.self, path: path)
        }
        mutating 
        func nestedContainer<NestedKey>(keyedBy:NestedKey.Type) throws 
            -> KeyedDecodingContainer<NestedKey>
        {
            let path:[CodingKey] = self.nextPath
            return .init(try self.next().decodeContainer(keyedBy: NestedKey.self, 
                path: path))
        }
        mutating 
        func nestedUnkeyedContainer() throws 
            -> UnkeyedDecodingContainer
        {
            let path:[CodingKey] = self.nextPath
            return try self.next().decodeContainer(keyedBy: Void.self, 
                path: path)
        }
        
        func superDecoder() -> Decoder
        {
            fatalError("unimplemented")
        }
    }
    
    func decodeNil() -> Bool
    {
        self.value.decodeNil()
    }
    func decode(_:Bool.Type) throws -> Bool
    {
        try self.value.decode(Bool.self)
    }
    func decode(_:Int.Type) throws -> Int
    {
        try self.value.decode(Int.self)
    }
    func decode(_:Int64.Type) throws -> Int64
    {
        try self.value.decode(Int64.self)
    }
    func decode(_:Int32.Type) throws -> Int32
    {
        try self.value.decode(Int32.self)
    }
    func decode(_:Int16.Type) throws -> Int16
    {
        try self.value.decode(Int16.self)
    }
    func decode(_:Int8.Type) throws -> Int8
    {
        try self.value.decode(Int8.self)
    }
    func decode(_:UInt.Type) throws -> UInt
    {
        try self.value.decode(UInt.self)
    }
    func decode(_:UInt64.Type) throws -> UInt64
    {
        try self.value.decode(UInt64.self)
    }
    func decode(_:UInt32.Type) throws -> UInt32
    {
        try self.value.decode(UInt32.self)
    }
    func decode(_:UInt16.Type) throws -> UInt16
    {
        try self.value.decode(UInt16.self)
    }
    func decode(_:UInt8.Type) throws -> UInt8
    {
        try self.value.decode(UInt8.self)
    }
    func decode(_:Float.Type) throws -> Float
    {
        try self.value.decode(Float.self)
    }
    func decode(_:Double.Type) throws -> Double
    {
        try self.value.decode(Double.self)
    }
    func decode(_:String.Type) throws -> String
    {
        try self.value.decode(String.self)
    }
    func decode<T>(_:T.Type) throws -> T 
        where T:Decodable
    {
        try self.value.decode(T.self, path: self.codingPath)
    }
    
    func container<Key>(keyedBy _:Key.Type) throws -> KeyedDecodingContainer<Key> 
        where Key:CodingKey 
    {
        .init(try self.value.decodeContainer(keyedBy: Key.self, path: self.codingPath))
    }
    func unkeyedContainer() throws -> UnkeyedDecodingContainer
    {
        try self.value.decodeContainer(keyedBy: Void.self, path: self.codingPath)
    }
    func singleValueContainer() -> SingleValueDecodingContainer
    {
        self
    }
}
