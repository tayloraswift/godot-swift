struct Words:Hashable, Comparable, CustomStringConvertible
{
    enum Normalization 
    {
        typealias Patterns = [String: (tail:[String], normalized:[String])] 
        
        static 
        let general:Patterns = 
        [
            "Anti"      : (["Aliasing"],    ["Antialiasing"]),
            "Counter"   : (["Clockwise"],   ["Counterclockwise"]),
            "Ycbcr"     : (["Sep"],         ["Ycbcr", "Separate"]),
            "Hi"        : (["Limit"],       ["High", "Limit"]),
            "Lo"        : (["Limit"],       ["Low", "Limit"]),
            "Get"       : (["Var"],         ["Get", "Variant"]),
            "Put"       : (["Var"],         ["Put", "Variant"]),
            "Local"     : (["Var"],         ["Local", "Variable"]),
            "Var"       : (["Name"],        ["Variable", "Name"]),
            
            "Accel"     : ([], ["Acceleration"]),
            "Anim"      : ([], ["Animation"]),
            "Arg"       : ([], ["Argument"]),
            "Assign"    : ([], ["Assignment"]),
            "Brothers"  : ([], ["Siblings"]),
            "Char"      : ([], ["Character"]),
            "Coord"     : ([], ["Coordinate"]),
            "Coords"    : ([], ["Coordinates"]),
            "Dest"      : ([], ["Destination"]),
            "Dir"       : ([], ["Directory"]),
            "Dirs"      : ([], ["Directories"]),
            "Elem"      : ([], ["Element"]),
            "Env"       : ([], ["Environment"]),
            "Expo"      : ([], ["Exponential"]),
            "Fract"     : ([], ["Fractional"]),
            "Func"      : ([], ["Function"]),
            "Funcv"     : ([], ["Functionv"]),
            "Idx"       : ([], ["Index"]),
            "Interp"    : ([], ["Interpolation"]),
            "Jpg"       : ([], ["Jpeg"]),
            "Len"       : ([], ["Length"]),
            "Lib"       : ([], ["Library"]),
            //"Mult"      : ([], ["Multiply"]),
            "Maximum"   : ([], ["Max"]),
            "Minimum"   : ([], ["Min"]),
            "Mem"       : ([], ["Memory"]),
            "Mul"       : ([], ["Multiply"]),
            "Op"        : ([], ["Operator"]),
            "Param"     : ([], ["Parameter"]),
            "Poly"      : ([], ["Polygon"]),
            "Pos"       : ([], ["Position"]),
            "Premult"   : ([], ["Premultiply"]),
            "Rect"      : ([], ["Rectangle"]),
            "Ref"       : ([], ["Reference"]),
            "Regen"     : ([], ["Regenerate"]),
            "Src"       : ([], ["Source"]),
            "Subdiv"    : ([], ["Subdivision"]),
            "Surf"      : ([], ["Surface"]),
            //"Sub"       : ([], ["Subtract"]),
            "Tex"       : ([], ["Texture"]),
            "Vec"       : ([], ["Vector"]),
            "Verts"     : ([], ["Vertices"]),
            
            "Areaangular"   : ([], ["Area", "Angular"]),
            "Fadein"        : ([], ["Fade", "In"]),
            "Fadeout"       : ([], ["Fade", "Out"]),
            "Minsize"       : ([], ["Min", "Size"]),
            "Maxsize"       : ([], ["Max", "Size"]),
            "Navpoly"       : ([], ["Navigation", "Polygon"]),
            "Rid"           : ([], ["Resource", "Identifier"]),
            "Texid"         : ([], ["Texture", "Id"]),
        ]
        static 
        let constants:Patterns = 
        [
            "Kp"        : ([], ["Keypad"]),
            "Xbutton1"  : ([], ["Back"]),
            "Xbutton2"  : ([], ["Forward"]),
            "Exp"       : ([], ["Exponential"]),
            "Enum"      : ([], ["Enumeration"]),
            "Accel"     : ([], ["Acceleration"]),
            "Dir"       : ([], ["Directory"]),
            "Concat"    : ([], ["Concatenation"]),
            "Intl"      : ([], ["Internationalized"]),
            "Noeditor"  : ([], ["No", "Editor"]),
            "Noscript"  : ([], ["No", "Script"]),
        ]
    }
    
    private 
    var components:[String]
    
    static 
    func < (lhs:Self, rhs:Self) -> Bool 
    {
        "\(lhs)" < "\(rhs)"
    }
    
    // symbol name mappings 
    static 
    func name(class original:String) -> Self
    {
        let reconciled:String 
        switch original
        {
        case "Object":          reconciled = "AnyDelegate"
        case "Reference":       reconciled = "AnyObject"
        // fix problematic names 
        case "NativeScript":    reconciled = "NativeScriptDelegate"
        case let original:      reconciled = original 
        }
        
        return Self.split(pascal: reconciled)
            .normalized(patterns: Normalization.general) 
    }
    static 
    func name(enumeration original:String, scope:Words) -> Self
    {
        let reconciled:String
        switch ("\(scope)", original)
        {
        // fix problematic names 
        case ("VisualShader", "Type"):  reconciled = "Shader"
        case ("IP", "Type"):            reconciled = "Version"
        case let (_, original):         reconciled = original
        }
        
        return Self.split(pascal: reconciled)
            .normalized(patterns: Normalization.general)
            .factoring(out: scope, forbidding: [["_"], ["Type"]])
    }
    
    static 
    func split(pascal:String) -> Self 
    {
        var words:[String]  = []
        var word:String     = ""
        for character:Character in pascal 
        {
            if  character.isUppercase, 
                let last:Character = word.last, last.isLowercase 
            {
                words.append(word)
                word = ""
            }
            // remove internal underscores (keep leading underscores)
            if character == "_", !word.isEmpty
            {
                if word.isEmpty 
                {
                    words.append("_")
                }
                else 
                {
                    words.append(word)
                }
                word = ""
            }
            else 
            {
                // if starting a new word, make sure it starts with an 
                // uppercase letter (needed for `Tracking_status`)
                if word.isEmpty, character.isLowercase 
                {
                    word.append(character.uppercased())
                }
                else 
                {
                    word.append(character)
                }
            }
        }
        
        if !word.isEmpty 
        {
            words.append(word)
        }
        return .init(components: words)
    }
    
    static 
    func split(snake:String) -> Self
    {
        let components:[String] = snake.uppercased().split(separator: "_").map
        { 
            if let head:Character = $0.first 
            {
                return "\(head)\($0.dropFirst().lowercased())"
            }
            else 
            {
                // should never have empty subsequences 
                return .init($0)
            }
        }
        // preserve leading underscore if present 
        if snake.prefix(1) == "_" 
        {
            return .init(components: ["_"] + components)
        }
        else 
        {
            return .init(components: components)
        }
    }
    
    // expands unswifty abbreviations, and fix some strange spellings 
    func normalized(patterns:Normalization.Patterns) -> Self
    {
        var components:[String] = []
        var i:Int               = self.components.startIndex 
        while i < self.components.endIndex 
        {
            let original:String = self.components[i]
            
            i += 1
            
            if  let pattern:(tail:[String], normalized:[String]) = patterns[original], 
                self.components.dropFirst(i).prefix(pattern.tail.count) == pattern.tail[...]
            {
                components.append(contentsOf: pattern.normalized)
                i += pattern.tail.count
            }
            else 
            {
                components.append(original)
            }
        }
        
        return .init(components: components)
    }
    // strips meaningless prefixes
    func factoring(out other:Self, forbidding forbidden:Set<Self> = [["_"]]) 
        -> Self
    {
        // most nested types have the form 
        // scope:   'Foo' 'Bar' 'Baz' 
        // nested:        'Bar' 'Baz' 'Qux'
        // 
        // we want to reduce it to just 'Qux'
        outer:
        for i:Int in (0 ... min(self.components.count, other.components.count)).reversed()
            where other.components.suffix(i) == self.components.prefix(i)
        {
            let components:[String] = .init(self.components.dropFirst(i))
            // do not factor if it would result in an identifier beginning with a numeral 
            if let first:Character = components.first?.first, first.isNumber
            {
                continue outer 
            }
            let candidate:Self = components.isEmpty ? ["_"] : .init(components: components)
            guard !forbidden.contains(candidate)
            else 
            {
                continue outer 
            }
            return candidate 
        }
        return self
    }
    
    static 
    func greatestCommonPrefix(among group:[Self]) -> Self 
    {
        var prefix:[String] = []
        for i:Int in 0 ..< (group.map(\.components.count).min() ?? 0)
        {
            let unique:Set<String> = .init(group.map(\.components[i]))
            if let first:String = unique.first, unique.count == 1 
            {
                prefix.append(first)
            }
            else 
            {
                break 
            }
        }
        return .init(components: prefix)
    }
    
    var description:String 
    {
        self.components.joined()
    }
    var camelcased:String 
    {
        if let head:String = self.components.first?.lowercased() 
        {
            let normalized:String 
            if self.components.dropFirst().isEmpty
            {
                // escape keywords 
                switch head 
                {
                case    "init":
                    normalized = "initialize"
                case    "func":            
                    normalized = "function"
                case    "continue", "class", "default", "in", "import", 
                        "operator", "repeat", "self", "static", "var":  
                    normalized = "`\(head)`"
                case let head: 
                    normalized = head 
                }
            }
            else 
            {
                normalized = head 
            }
            // if first component is underscore, lowercase the second component too
            if  normalized == "_", 
                let second:String = self.components.dropFirst().first?.lowercased()
            {
                return "\(normalized)\(second)\(self.components.dropFirst(2).joined())"
            }
            else 
            {
                return "\(normalized)\(self.components.dropFirst().joined())"
            }
        }
        else 
        {
            return self.description
        }
    }
}
extension Words:ExpressibleByArrayLiteral 
{
    init(arrayLiteral:String...)
    {
        self.init(components: arrayLiteral)
    }
}
