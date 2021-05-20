extension Godot.Class.Node 
{
    var documentation:String 
    {
        let constants:[(key:Constant.Key, value:Constant)] = self.constants
        .sorted 
        {
            $0.value.name < $1.value.name
        }
        let properties:[(key:Property.Key, value:Property)] = self.properties
        .sorted 
        {
            $0.key.name < $1.key.name
        }
        let methods:[(key:Method.Key, value:Method)]        = self.methods
        .sorted 
        {
            $0.key.name < $1.key.name
        }
        
        let page:String = "https://docs.godotengine.org/en/stable/classes/class_\(self.symbol.lowercased()).html"
        
        return Source.fragment 
        {
            """
            /// class \(self.namespace).\(self.name)
            """
            if let parent:Godot.Class.Node = self.parent 
            {
                """
                /// :   \(parent.namespace).\(parent.name)
                """
            }
            if self.children.isEmpty 
            {
                """
                /// final 
                """
            }
            """
            ///     The [`Godot::\(self.symbol)`](\(page)) class.
            
            """
            
            for enumeration:Enumeration in self.enumerations 
            {
                """
                /// struct \(self.namespace).\(self.name).\(enumeration.name)
                /// :   Swift.Hashable
                ///     The [`Godot::\(self.symbol)::\(enumeration.symbol)`](\(page)#enumerations) enumeration.
                
                /// let \(self.namespace).\(self.name).\(enumeration.name).value:Swift.Int 
                ///     The raw value of this enumeration case.
                
                """
                for (name, _):(Words, Int) in enumeration.cases 
                {
                    """
                    /// static let \(self.namespace).\(self.name).\(enumeration.name).\(name.camelcased(escaped: false)):Self 
                    
                    """
                }
            }
            
            if      self.namespace  == .root, 
                    self.name       == .split(pascal: "AnyDelegate")
            {
                """
                /// func \(self.namespace).\(self.name).emit<Signal>(signal:as:)
                /// final 
                /// where Signal:Godot.Signal
                ///     Emits a value as the specified signal type.
                /// - value :   Signal.Value 
                ///     A signal value.
                /// - _     :   Signal.Type 
                ///     The signal type to emit the given `value` as.
                
                """
            }
            else if self.namespace  == .root, 
                    self.name       == .split(pascal: "AnyObject")
            { 
                """
                /// func \(self.namespace).\(self.name).retain()
                /// final 
                /// @   discardableResult
                ///     Performs an unbalanced retain.
                /// - ->    : Swift.Bool 
                ///     This method should always return `true`.
                
                /// func \(self.namespace).\(self.name).release()
                /// final 
                /// @   discardableResult
                ///     Performs an unbalanced release.
                /// - ->    : Swift.Bool 
                ///     `true` if `self` was uniquely-referenced before performing 
                ///     the release, `false` otherwise.
                
                """
            }
            
            for (key, constant):(Constant.Key, Constant) in constants 
            {
                """
                /// static let \(self.namespace).\(self.name).\(constant.name.camelcased(escaped: false)):Swift.Int
                ///     The [`Godot::\(self.symbol)::\(key.symbol)`](\(page)#constants) constant. 
                /// 
                ///     The raw value of this constant is `\(constant.value)`.
                
                """
            }
            
            for (key, property):(Property.Key, Property) in properties  
            {
                let (parameterization, generics, constraints):
                (
                    Godot.SwiftType.Parameterized, [String], [String]
                ) 
                = 
                property.type.swift.parameterized(as: "T")
                
                let type:String         = generics.isEmpty ? parameterization.outer : property.type.canonical
                let modifiers:[String]  = 
                    (property.is.final    ? ["final"] : []) 
                    + 
                    (property.is.override ? ["override"] : [])
                
                """
                /// var \(self.namespace).\(self.name).\(key.name.camelcased(escaped: false)):\(type) { get \(property.set == nil ? "" : "set ")}
                """
                if !modifiers.isEmpty
                {
                    """
                    /// \(modifiers.joined(separator: " "))
                    """
                }
                """
                ///     The [`Godot::\(self.symbol)::\(key.symbol)`](\(page)#properties) property.
                
                """
            }
        }
    }
}
