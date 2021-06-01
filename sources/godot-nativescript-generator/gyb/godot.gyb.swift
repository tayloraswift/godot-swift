extension Godot
{
    @Source.Code 
    static 
    var swift:String
    {
        let tree:Class.Tree = .load(api: (3, 3, 0))
        // `withExtendedLifetime` is important because properties hold `unowned`
        //  references to upstream nodes 
        let classes:
        [
            (
                node:Class.Node, 
                functions:String?, 
                definition:String
            )
        ] 
        = 
        withExtendedLifetime(tree.root)
        {
            tree.root.preorder.compactMap
            {
                ($0, $0.functions, $0.definition)
            }
            .sorted 
            {
                // keeps the generated code stable
                $0.node.name < $1.node.name
            }
        }
        
        Source.text(from: "fragments",  "external.swift.part")
        Source.text(from: "fragments",  "runtime.swift.part")
        Source.text(from: "fragments",  "variant.swift.part")
        Source.text(from: "fragments",  "variant-list.swift.part")
        Source.text(from: "fragments",  "variant-map.swift.part")
        Source.text(from: "fragments",  "variant-nodepath.swift.part")
        Source.text(from: "fragments",  "aggregate.swift.part")
        
        Source.section(name:            "variant-raw.swift.part")
        {
            VariantRaw.swift
        }
        Source.section(name:            "variant-vector.swift.part")
        {
            VariantVector.swift
        }
        Source.section(name:            "variant-rectangle.swift.part")
        {
            VariantRectangle.swift
        }
        Source.text(from: "fragments",  "variant-string.swift.part")
        Source.section(name:            "variant-array.swift.part")
        {
            VariantArray.swift
        }
        Source.section(name:            "convention.swift.part")
        {
            // determine longest required icall template 
            Convention.swift(arity: tree.root.preorder
                .flatMap{ $0.methods.values.map(\.parameters.count) }
                .max() ?? 0)
        }
        Source.section(name:            "delegates.swift.part")
        {
            "extension Godot"
            Source.block 
            {
                """
                // type metadata table
                static 
                let DelegateTypes:[AnyDelegate.Type] =
                """
                Source.block(delimiters: ("[", "]"))
                {
                    for node:Class.Node in classes.map(\.node)
                    {
                        "\(node.namespace).\(node.name).self,"
                    }
                }
            }
        }
        
        Source.section(name:            "functions.swift.part")
        {
            // cannot override static properties, so we need to store the 
            // method bindings out-of-line
            """
            extension Godot
            {
                fileprivate 
                enum Functions 
                {
                }
            }
            extension Godot.Functions
            """
            Source.block 
            {
                for (node, functions, _):(Class.Node, String?, String) in classes
                {
                    if let functions:String = functions 
                    {
                        """
                        enum \(node.name)
                        """
                        Source.block 
                        {
                            functions
                        }
                    }
                }
            }
        }
        Source.section(name:            "global.swift.part")
        {
            GlobalConstants.swift(tree.constants)
        }
        // nest the classes in appropriate extension scopes, so we can omit `Godot`
        // prefixes 
        """
        extension Godot
        """
        Source.block 
        {
            for (node, _, definition):(Class.Node, String?, String) in classes
                where node.namespace == .root
            {
                Source.section(name: "classes", "\(node.name).swift.part")
                {
                    definition 
                }
            }
            """
            /// enum Godot.Unmanaged 
            ///     A namespace for Godot types that are not memory-managed by the 
            ///     Godot engine.
            /// #   (godot-namespaces)
            enum Unmanaged 
            """
            Source.block 
            {
                for (node, _, definition):(Class.Node, String?, String) in classes
                    where node.namespace == .unmanaged
                {
                    Source.section(name: "classes", "\(node.name).swift.part")
                    {
                        definition 
                    }
                }
            }
            """
            /// enum Godot.Singleton 
            ///     A namespace for Godot singleton classes.
            /// #   (godot-namespaces)
            enum Singleton 
            """
            Source.block 
            {
                for (node, _, definition):(Class.Node, String?, String) in classes
                    where node.namespace == .singleton
                {
                    Source.section(name: "classes", "\(node.name).swift.part")
                    {
                        definition 
                    }
                }
            }
        }
    }
}

extension Godot.Class.Node 
{
    var url:String 
    {
        "https://docs.godotengine.org/en/stable/classes/class_\(self.symbol.lowercased()).html"
    }
    
    // creates an entrapta page tag. replaces underscores with "-" hyphens
    func tag(_ components:String...) -> String 
    {
        .init("class-\(self.symbol)-\(components.joined(separator: "-"))".map 
        {
            $0 == "_" ? "-" : $0
        })
    }
    
    var functions:String?
    {
        guard !self.methods.isEmpty
        else 
        {
            return nil 
        }
        // sort to keep the generated code stable
        let methods:[(key:Method.Key, value:Method)] = self.methods
        .sorted 
        {
            $0.key.name < $1.key.name
        }
        return 
            """
            static 
            let \(methods.map 
            {
                """
                \($0.key.name.camelcased):Godot.Function = 
                        Godot.Function.bind(method: "\($0.key.symbol)", from: \(self.namespace).\(self.name).self)
                """
            }.joined(separator: ",\n    "))
            """
    }
    var definition:String
    {
        // sort to keep the generated code stable
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
        
        // only used for the `symbol` computed property, since classes themselves 
        // cannot be marked `override`
        let modifiers:String? 
        switch (self.children.isEmpty, self.parent)
        {
        case (true , nil  ):    modifiers = "final"
        case (true , _?   ):    modifiers = "final override"
        case (false, _?   ):    modifiers = "override"
        case (false, nil  ):    modifiers = nil 
        }
        
        return Source.fragment
        {
            // doccomment 
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
            if      self.namespace  == .root, 
                    self.name       == ["Any", "Delegate"]
            {
                """
                /// :   Godot.Variant
                ///     The base class from which all Godot classes inherit from. 
                /// 
                ///     This type correspond to the `Godot::Object` type in GDScript. 
                ///     In Swift, the term *object* refers exclusively to 
                ///     reference-counted values, so *Godot Swift* uses the term 
                ///     *delegate* to refer to what is otherwise known as an 
                ///     “object” elsewhere in the Godot world.
                /// 
                ///     Reference-counted Godot delegates — that is, classes that 
                ///     inherit from `Godot::Reference` — correspond to the 
                ///     *Godot Swift* type [`Godot.AnyObject`], which in turn, 
                ///     inherits from [`AnyDelegate`].
                /// 
                ///     > warning: 
                ///     Do not confuse [`Godot.AnyObject`] with [`Godot.AnyDelegate`]. 
                ///     [`Godot.AnyDelegate`] is the root base class, not [`Godot.AnyObject`].
                /// 
                ///     Godot delegates are fully bridged to Swift’s dynamic type 
                ///     system. You can dynamically downcast to a subclass using 
                ///     the `as?` downcast operator.
                /**
                        ```swift 
                        let delegate:Godot.AnyDelegate              = ... 
                        guard let mesh:Godot.Unmanaged.MeshInstance = 
                            delegate as? Godot.Unmanaged.MeshInstance 
                        else 
                        {
                            ...
                        }
                        ```
                **/
                ///     You can upcast to a superclass using the `as` upcast 
                ///     operator, just like any other Swift `class`. 
                /**
                        ```swift 
                        let resource:Godot.Resource = ... 
                        let object:Godot.AnyObject  = resource as Godot.AnyObject
                        ```
                **/
                ///     Emit a signal using the [`emit(signal:as:)`] method. It 
                ///     has the following signature: 
                /**
                        ```swift 
                        final 
                        func emit<Signal>(signal value:Signal.Value, as _:Signal.Type)
                            where Signal:Godot.Signal 
                        ```
                **/
                ///     See the [using signals](https://github.com/kelvin13/godot-swift/tree/master/examples#signals) 
                ///     tutorial for more on how to use this method.
                ///
                ///     Almost all of the methods, properties, constants, and 
                ///     enumerations in the Godot engine API are available on the 
                ///     *Godot Swift* delegate classes. GDScript properties are 
                ///     exposed as computed Swift properties of the canonical 
                ///     variant type. Some properties allow you to avoid unnecessary 
                ///     type conversions by providing generic getter and setter 
                ///     methods. 
                /// 
                ///     Generic getters are spelled `\\(property name)(as:)`, 
                ///     and generic setters are spelled `set(\\(property name):)`.
                /**
                        ```swift 
                        let mesh:Godot.ArrayMesh = ... 

                        let float32:Vector3<Float32>.Rectangle = mesh.customAabb 
                        let float64:Vector3<Float64>.Rectangle = mesh.customAabb(as: Vector3<Float64>.Rectangle.self)
                        mesh.set(customAabb: float64)
                        ```
                **/
                ///     Most GDScript methods are exposed as generic functions 
                ///     over appropriate type parameterizations. For example, all 
                ///     of the following are valid ways to call the 
                ///     [`ArrayMesh.surfaceFindByName(_:as:)`] method:
                /**
                        ```swift 
                        let mesh:Godot.ArrayMesh    = ... 
                        let godot:Godot.String      = ...
                        let swift:Swift.String      = ...

                        let index32:Int32   = mesh.surfaceFindByName(godot, as: Int32.self)
                        let index32:Int32   = mesh.surfaceFindByName(swift, as: Int32.self)
                        let index:Int       = mesh.surfaceFindByName(godot, as: Int.self)
                        let index:Int       = mesh.surfaceFindByName(swift, as: Int.self)
                        ```
                **/
                ///     *Godot Swift* transforms all Godot symbol names 
                ///     (including argument labels) through a predefined set of 
                ///     string transformations, which convert Godot symbols to 
                ///     `camelCase` and expand unswifty abbreviations, among 
                ///     other things. 
                /// 
                ///     Godot delegates are memory-managed by Swift. Keep in mind 
                ///     that this will only protect you from memory leaks if the 
                ///     delegate class itself is a memory-managed class 
                ///     (inherits from [`Godot.AnyObject`]). To help you keep 
                ///     track of this, all unmanaged Godot delegates are scoped 
                ///     under the namespace [`Godot.Unmanaged`].
                ///
                ///     Use the [`free()`] method to manually deallocate an 
                ///     unmanaged delegate. 
                ///     [Use this with caution](https://docs.godotengine.org/en/stable/classes/class_object.html#class-object-method-free),
                ///     just as in GDScript.
                /**
                        ```swift 
                        let delegate:Godot.AnyDelegate = ... 
                        delegate.free()
                        ```
                **/
                ///     > warning:
                ///     An instance of static type [`Godot.AnyDelegate`] may, of 
                ///     course, be an instance of [`Godot.AnyObject`], or one of 
                ///     its subclasses. Make sure an delegate of static type 
                ///     [`AnyDelegate`] is actually an unmanaged delegate before 
                ///     manually deallocating it.
                /// #   [Getting the GDScript class name of a delegate](\(self.tag("class", "name", "builtin")))
                /// #   [Low-level functionality](\(self.tag("builtins")))
                /// #   [Using signals](\(self.tag("signal", "usage")))
                """
            }
            else if self.namespace  == .root, 
                    self.name       == ["Any", "Object"]
            {
                """
                ///     The subclass from which all reference-counted Godot 
                ///     classes inherit from. 
                /// #   [Getting the GDScript class name of a delegate](\(self.tag("class", "name", "builtin")))
                /// #   [Low-level functionality](\(self.tag("builtins")))
                /// #   [Manual memory management](\(self.tag("manual", "reference", "counting")))
                """
            }
            else 
            {
                """
                ///     The [`Godot::\(self.symbol)`](\(self.url)) class.
                /// #   [Getting the GDScript class name of a delegate](\(self.tag("class", "name", "builtin")))
                """
            }
            """
            /// #   [Constants](\(self.tag("constants")))
            /// #   [Properties](\(self.tag("properties")))
            /// #   [Generic property accessors](\(self.tag("property", "accessors")))
            """
            
            if let parent:Godot.Class.Node = self.parent 
            {
                if self.children.isEmpty 
                {
                "final" 
                }
                "class \(self.name):\(parent.namespace).\(parent.name)"
            }
            else 
            {
                "class \(self.name)"
            }
            Source.block 
            {
                """
                /// class var \(self.namespace).\(self.name).symbol:Swift.String { get }
                """
                if let modifiers:String = modifiers 
                {
                    """
                    /// \(modifiers)
                    """
                }
                """
                ///     The GDScript name (`"\(self.symbol)"`) of this class.
                /// 
                ///     This property is is provided as a *Godot Swift* builtin.
                ///     Accessing it is roughly equivalent to calling 
                ///     the [`AnyDelegate.getClass(as:)`] method, but does not 
                ///     call into game engine runtime.
                /// #   (\(self.tag("class", "name", "builtin")))
                \(modifiers.map{ "\($0) " } ?? "")class 
                var symbol:Swift.String { "\(self.symbol)" }
                """
                
                if      self.namespace  == .root, 
                        self.name       == ["Any", "Delegate"]
                {
                    // Godot.AnyDelegate has special behavior:
                    """
                    /// let \(self.namespace).\(self.name).core:UnsafeMutableRawPointer 
                    /// final 
                    ///     The raw pointer to the delegate instance 
                    ///     wrapped by this Swift class instance.
                    /// 
                    ///     This pointer is not the same as the Swift instance 
                    ///     pointer to `self`.
                    /// 
                    ///     Do not use this pointer unless you really know what 
                    ///     you are doing.
                    /// #   (\(self.tag("builtins")))
                    final 
                    let core:UnsafeMutableRawPointer 
                    
                    /// required init \(self.namespace).\(self.name).init(retained:)
                    ///     Unsafely creates an instance of this class from 
                    ///     a raw delegate pointer. 
                    /// 
                    ///     The `core` pointer is assumed to have been properly 
                    ///     type-checked. If [`Self`] is [`Godot.AnyObject`], or 
                    ///     one of its subclasses, it is also assumed to have 
                    ///     already been retained, and will be released when 
                    ///     `self` is deinitialized.
                    /// 
                    ///     Do not use this initializer unless you really know 
                    ///     what you are doing.
                    /// - core:UnsafeMutableRawPointer
                    /// #   (\(self.tag("builtins")))
                    required
                    init(retained core:UnsafeMutableRawPointer) 
                    {
                        self.core = core
                    }
                    /// required init \(self.namespace).\(self.name).init(retaining:)
                    ///     Unsafely creates an instance of this class from 
                    ///     a raw delegate pointer. 
                    /// 
                    ///     The `core` pointer is assumed to have been properly 
                    ///     type-checked. If [`Self`] is [`Godot.AnyObject`], or 
                    ///     one of its subclasses, it will be retained, and 
                    ///     will be released when `self` is deinitialized.
                    /// 
                    ///     Do not use this initializer unless you really know 
                    ///     what you are doing.
                    /// - core:UnsafeMutableRawPointer
                    /// #   (\(self.tag("builtins")))
                    required
                    init(retaining core:UnsafeMutableRawPointer) 
                    {
                        self.core = core
                    }
                    
                    /// func \(self.namespace).\(self.name).connect<Signal, S>(_:to:in:context:flags:) throws 
                    ///     Connects a signal from this delegate to the given method in 
                    ///     the given target delegate.
                    /// 
                    ///     This method will throw a [`Godot.Error`] if the 
                    ///     connection cannot be made. It will also throw an 
                    ///     error if the connection already exists, unless the 
                    ///     original connection was marked as [`(ConnectFlags).referenceCounted`].
                    /// final 
                    /// where Signal:Godot.Signal, S:StringRepresentable 
                    /// - signal:Signal.Type 
                    ///     The signal to connect. 
                    /// - method:S 
                    ///     The name of the method in `target` to connect `signal` to.
                    /// - target:AnyDelegate 
                    ///     The delegate containing the `method` to connect `signal` to.
                    /// - context:List 
                    ///     Additional bound parameters to add to this 
                    ///     connection. The default value is an empty list. 
                    /// - flags:ConnectFlags 
                    ///     Flags specifying how this connection should be made.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (1:\(self.tag("signal", "usage")))
                    final 
                    func connect<Signal, S>(_ signal:Signal.Type, to method:S, in target:AnyDelegate, 
                        context:List = [], flags:ConnectFlags)
                        throws 
                        where Signal:Godot.Signal, S:StringRepresentable 
                    {
                        try self.connect(signal.name, to: method, in: target, context: context, flags: flags)
                    }
                    /// func \(self.namespace).\(self.name).connect<S0, S1>(_:to:in:context:flags:) throws 
                    ///     Connects a signal, by string name, from this delegate 
                    ///     to the given method in the given target delegate.
                    /// 
                    ///     This method will throw a [`Godot.Error`] if the 
                    ///     connection cannot be made. It will also throw an 
                    ///     error if the connection already exists, unless the 
                    ///     original connection was marked as [`(ConnectFlags).referenceCounted`].
                    /// final 
                    /// where S0:StringRepresentable, S1:StringRepresentable 
                    /// - signal:S0 
                    ///     The string name of the signal to connect. 
                    /// - method:S1 
                    ///     The name of the method in `target` to connect `signal` to.
                    /// - target:AnyDelegate 
                    ///     The delegate containing the `method` to connect `signal` to.
                    /// - context:List 
                    ///     Additional bound parameters to add to this 
                    ///     connection. The default value is an empty list. 
                    /// - flags:ConnectFlags 
                    ///     Flags specifying how this connection should be made.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (1:\(self.tag("signal", "usage")))
                    final 
                    func connect<S0, S1>(_ signal:S0, to method:S1, in target:AnyDelegate, 
                        context:List = [], flags:ConnectFlags)
                        throws 
                        where S0:StringRepresentable, S1:StringRepresentable 
                    {
                        let status:Int64 = Godot.Functions.AnyDelegate.connect(self: self, 
                            Godot.String.init(signal), 
                            target as AnyDelegate?, 
                            Godot.String.init(method), 
                            context, 
                            Int64.init(flags.value))
                        guard status == 0 
                        else 
                        {
                            throw Godot.Error.init(value: Int.init(status))
                        }
                    }
                    
                    /// func \(self.namespace).\(self.name).disconnect<Signal, S>(_:from:in:) throws 
                    /// final 
                    /// where Signal:Godot.Signal, S:StringRepresentable 
                    ///     Disconnects a signal in this delegate from the given method in 
                    ///     the given target delegate.
                    /// 
                    ///     This method will throw a [`Godot.Error`] if the 
                    ///     connection does not exist. If the original connection 
                    ///     was marked as [`(ConnectFlags).referenceCounted`], 
                    ///     the connection will be released, but will only be 
                    ///     fully removed if it was uniquely-referenced.
                    /// - signal:Signal.Type 
                    ///     The signal to disconnect. 
                    /// - method:S 
                    ///     The name of the method in `target` to disconnect `signal` from.
                    /// - target:AnyDelegate 
                    ///     The delegate containing the `method` to disconnect `signal` from.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (2:\(self.tag("signal", "usage")))
                    final 
                    func disconnect<Signal, S>(_ signal:Signal.Type, from method:S, in target:AnyDelegate)
                        throws 
                        where Signal:Godot.Signal, S:StringRepresentable 
                    {
                        try self.disconnect(signal.name, from: method, in: target)
                    }
                    /// func \(self.namespace).\(self.name).disconnect<S0, S1>(_:from:in:) throws 
                    /// final 
                    /// where S0:StringRepresentable, S1:StringRepresentable 
                    ///     Disconnects a signal in this delegate, by string name, 
                    ///     from the given method in the given target delegate.
                    /// 
                    ///     This method will throw a [`Godot.Error`] if the 
                    ///     connection does not exist. If the original connection 
                    ///     was marked as [`(ConnectFlags).referenceCounted`], 
                    ///     the connection will be released, but will only be 
                    ///     fully removed if it was uniquely-referenced.
                    /// - signal:S0
                    ///     The signal to disconnect. 
                    /// - method:S1 
                    ///     The name of the method in `target` to disconnect `signal` from.
                    /// - target:AnyDelegate 
                    ///     The delegate containing the `method` to disconnect `signal` from.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (2:\(self.tag("signal", "usage")))
                    final 
                    func disconnect<S0, S1>(_ signal:S0, from method:S1, in target:AnyDelegate)
                        throws 
                        where S0:StringRepresentable, S1:StringRepresentable 
                    {
                        let status:Int64 = Godot.Functions.AnyDelegate.disconnect(self: self, 
                            Godot.String.init(signal), 
                            target as AnyDelegate?, 
                            Godot.String.init(method))
                        guard status == 0 
                        else 
                        {
                            throw Godot.Error.init(value: Int.init(status))
                        }
                    }
                    
                    /// func \(self.namespace).\(self.name).isConnected<Signal, S>(by:to:in:) 
                    /// final 
                    /// where Signal:Godot.Signal, S:StringRepresentable 
                    ///     Returns a boolean value indicating if the given signal in this 
                    ///     delegate is connected to the given method in the 
                    ///     target delegate.
                    /// - signal:Signal.Type 
                    ///     The signal to query the connection status of. 
                    /// - method:S 
                    ///     The name of a method in `target`.
                    /// - target:AnyDelegate 
                    ///     The delegate containing the `method` to query the connection 
                    ///     status of.
                    /// - ->    :Bool 
                    ///     `true` if this delegate is connected to `method` in `target`
                    ///     by `signal`; otherwise `false`.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (3:\(self.tag("signal", "usage")))
                    final 
                    func isConnected<Signal, S>(by signal:Signal.Type, to method:S, in target:AnyDelegate)
                        -> Bool 
                        where Signal:Godot.Signal, S:StringRepresentable 
                    {
                        self.isConnected(by: signal.name, to: method, in: target)
                    }
                    /// func \(self.namespace).\(self.name).isConnected<S0, S1>(by:to:in:) 
                    /// final 
                    /// where S0:StringRepresentable, S1:StringRepresentable 
                    ///     Returns a boolean value indicating if a signal, identified 
                    ///     by the given string name, in this 
                    ///     delegate is connected to the given method in the 
                    ///     target delegate.
                    /// - signal:S0
                    ///     The string name of the signal to query the connection status of. 
                    /// - method:S1 
                    ///     The name of a method in `target`.
                    /// - target:AnyDelegate 
                    ///     The delegate containing the `method` to query the connection 
                    ///     status of.
                    /// - ->    :Bool 
                    ///     `true` if this delegate is connected to `method` in `target`
                    ///     by `signal`; otherwise `false`.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (3:\(self.tag("signal", "usage")))
                    final 
                    func isConnected<S0, S1>(by signal:S0, to method:S1, in target:AnyDelegate)
                        -> Bool 
                        where S0:StringRepresentable, S1:StringRepresentable 
                    {
                        Godot.Functions.AnyDelegate.isConnected(self: self, 
                            Godot.String.init(signal), 
                            target as AnyDelegate?, 
                            Godot.String.init(method))
                    }
                    
                    /// func \(self.namespace).\(self.name).emit<Signal>(signal:as:)
                    /// final 
                    /// where Signal:Godot.Signal
                    ///     Emits a value as the specified signal type.
                    /// - value :   Signal.Value 
                    ///     A signal value.
                    /// - _     :   Signal.Type 
                    ///     The signal type to emit the given `value` as.
                    /// #   [See also](\(self.tag("signal", "usage")))
                    /// #   (0:\(self.tag("signal", "usage")))
                    final 
                    func emit<Signal>(signal value:Signal.Value, as _:Signal.Type)
                        where Signal:Godot.Signal 
                    {
                        var variants:[Godot.Unmanaged.Variant] = 
                            [.pass(retaining: Signal.name)]
                            +
                            Signal.interface.arguments.map
                            {
                                $0.witness(value)
                            }
                        defer 
                        {
                            for i:Int in variants.indices 
                            {
                                variants[i].release()
                            }
                        }
                        
                        Godot.Functions.AnyDelegate.emitSignal(self: self, variants: variants)
                    }
                    """
                }
                else if self.namespace  == .root, 
                        self.name       == ["Any", "Object"]
                {
                    // Godot.AnyObject has special behavior:
                    """
                    /// required init \(self.namespace).\(self.name).init(retained:)
                    ///     Unsafely creates an instance of this class from 
                    ///     a raw delegate pointer, without performing a 
                    ///     balanced retain.
                    /// 
                    ///     The `core` pointer is assumed to have been properly 
                    ///     type-checked, and is also assumed to have 
                    ///     already been retained. It will be released when 
                    ///     `self` is deinitialized.
                    /// 
                    ///     Do not use this initializer unless you really know 
                    ///     what you are doing.
                    /// - core:UnsafeMutableRawPointer
                    /// #   (\(self.tag("builtins")))
                    required
                    init(retained core:UnsafeMutableRawPointer) 
                    {
                        super.init(retained: core)
                    }
                    /// required init \(self.namespace).\(self.name).init(retaining:)
                    ///     Unsafely creates an instance of this class from 
                    ///     a raw delegate pointer, performing a balanced retain.
                    /// 
                    ///     The `core` pointer is assumed to have been properly 
                    ///     type-checked. It will be retained by this initializer, and 
                    ///     will be released when `self` is deinitialized.
                    /// 
                    ///     Do not use this initializer unless you really know 
                    ///     what you are doing.
                    /// - core:UnsafeMutableRawPointer
                    /// #   (\(self.tag("builtins")))
                    required 
                    init(retaining core:UnsafeMutableRawPointer) 
                    {
                        super.init(retaining: core)
                        guard self.retain()
                        else 
                        {
                            fatalError(
                                \"""
                                could not retain delegate of type \\
                                '\\(Swift.String.init(reflecting: Self.self))' at <\\(self.core)>
                                \""")
                        }
                    }
                    deinit
                    { 
                        self.release()
                    }
                    
                    /// func \(self.namespace).\(self.name).retain()
                    /// final 
                    /// @   discardableResult
                    ///     Performs an unbalanced retain.
                    /// - ->    : Bool 
                    ///     This method should always return `true`.
                    /// #   (\(self.tag("manual", "reference", "counting")))
                    @discardableResult
                    final
                    func retain() -> Bool 
                    {
                        Godot.Functions.AnyObject.reference(self: self) 
                    }
                    /// func \(self.namespace).\(self.name).release()
                    /// final 
                    /// @   discardableResult
                    ///     Performs an unbalanced release.
                    /// - ->    : Bool 
                    ///     `true` if `self` was uniquely-referenced before performing 
                    ///     the release, `false` otherwise.
                    /// #   (\(self.tag("manual", "reference", "counting")))
                    @discardableResult
                    final
                    func release() -> Bool 
                    {
                        Godot.Functions.AnyObject.unreference(self: self) 
                    }
                    """
                } 
                """
                
                """
                for (key, constant):(Constant.Key, Constant) in constants 
                {
                    """
                    /// static let \(self.namespace).\(self.name).\(constant.name.camelcased):Int
                    ///     The [`\(key.symbol)`](\(self.url)#constants) constant. 
                    /// 
                    ///     The raw value of this constant is `\(constant.value)`.
                    /// #   (1:\(self.tag("constants")))
                    static 
                    let \(constant.name.camelcased):Int = \(constant.value)
                    """
                }
                for enumeration:Enumeration in self.enumerations 
                {
                    """
                    /// struct \(self.namespace).\(self.name).\(enumeration.name)
                    /// :   Swift.Hashable
                    ///     The [`\(enumeration.symbol)`](\(self.url)#enumerations)
                    ///     enumeration.
                    /// #   (0:\(self.tag("constants")))
                    struct \(enumeration.name):Hashable  
                    """
                    Source.block 
                    {
                        """
                        /// let \(self.namespace).\(self.name).\(enumeration.name).value:Swift.Int 
                        ///     The raw value of this enumeration case.
                        let value:Int
                        
                        """
                        for (symbol, name, value):(String, Words, Int) in enumeration.cases 
                        {
                            """
                            /// static let \(self.namespace).\(self.name).\(enumeration.name).\(name.camelcased):Self 
                            ///     The [`\(symbol)`](\(self.url)#enumerations) constant.
                            /// 
                            ///     The raw value of this constant is `\(value)`.
                            static 
                            let \(name.camelcased):Self = .init(value: \(value))
                            """
                        }
                    }
                }
                """
                
                """
                for (key, property):(Property.Key, Property) in properties
                {
                    property.define(as: key.name.camelcased, originally: key.symbol, in: self)
                } 
                
                for (key, method):(Method.Key, Method) in methods 
                    where !method.is.hidden
                {
                    method.define(as: key.name.camelcased, originally: key.symbol, in: self)
                } 
            }
        }
    }
}
extension Godot.Class.Node.Property 
{
    func define(as name:String, originally symbol:String, in host:Godot.Class.Node) 
        -> String 
    {
        let function:Godot.Function = .init(domain: [], range: self.type)
        let getter:String           = 
            """
            Godot.Functions.\(self.get.node.name).\
            \(self.get.node.methods[self.get.index].key.name.camelcased)
            """
        let setter:String?          = self.set.map 
        {
            """
            Godot.Functions.\($0.node.name).\
            \($0.node.methods[$0.index].key.name.camelcased)
            """
        }
        
        let modifiers:String? 
        switch (self.is.final, self.is.override)
        {
        case (true , false):    modifiers = "final"
        case (true , true ):    modifiers = "final override"
        case (false, true ):    modifiers = "override"
        case (false, false):    modifiers = nil 
        }
        
        let expressions:[String] = ["self: self"] + (self.index.map{ ["\($0)"] } ?? [])
        let body:(get:String, set:String?) 
        body.get = Source.block 
        {
            """
            let result:\(function.range.inner) = \(getter)\(Source.inline(list: expressions))
            return \(function.range.outer(expression: "result"))
            """
        }
        body.set = setter.map 
        {
            (setter:String) -> String in 
            Source.block 
            {
                """
                \(setter)\(Source.inline(list: 
                    expressions + [function.range.inner(expression: "value")]))
                """
            }
        }
        return Source.fragment 
        {
            // create doccomment tag for this accessor group. 
            let tag:String = host.tag(symbol, "accessor")
            // emit doccomment 
            """
            /// var \(host.namespace).\(host.name).\(name):\(function.range.canonical) \
            { \(body.set == nil ? "get" : "get set") }
            """
            if let modifiers:String = modifiers 
            {
                """
                /// \(modifiers)
                """
            }
            """
            ///     The [`\(symbol)`](\(host.url)#properties) instance property.
            /// #   [See also](\(tag))
            /// #   (0:\(host.tag("properties")))
            /// #   (\(tag))
            """
            
            if let modifiers:String = modifiers 
            {
                modifiers
            }
            """
            var \(name):\(function.range.canonical)
            """
            if function.parameters.isEmpty // no generics 
            {
                if let set:String = body.set 
                {
                    Source.block 
                    {
                        "get" 
                        body.get 
                        "set(value)"
                        set
                    }
                }
                else 
                {
                    body.get 
                }
            }
            else 
            {
                if let _:String = body.set 
                {
                    Source.block 
                    {
                        """
                        get 
                        {
                            self.\(name)(as: \(function.range.canonical).self)
                        }
                        set(value) 
                        {
                            self.set(\(name): value)
                        }
                        """
                    }
                }
                else 
                {
                    Source.block 
                    {
                        "self.\(name)(as: \(function.range.canonical).self)"
                    }
                } 
                
                // emit generic accessors 
                """
                /// func \(host.namespace).\(host.name).\(name)\(Source.inline(angled: function.parameters))(as:)
                """
                if let modifiers:String = modifiers 
                {
                    """
                    /// \(modifiers)
                    """
                }
                // constraints need to fit on one line for entrapta doccomment
                """
                /// where \(function.constraints.joined(separator: ", "))
                ///     Loads this delegate’s [`\(name)`] property as the specified type.
                /// - type  :\(function.range.outer).Type
                /// - ->    :\(function.range.outer)
                /// #   [See also](\(tag))
                /// #   (0:\(host.tag("property", "accessors")))
                /// #   (\(tag))
                """
                
                if let modifiers:String = modifiers 
                {
                    modifiers
                }
                """
                func \(name)\(Source.inline(angled: function.parameters))\
                (as _:\(function.range.outer).Type) -> \(function.range.outer) \
                \(Source.constraints(function.constraints))
                """
                body.get
                if let set:String = body.set
                {
                    """
                    /// func \(host.namespace).\(host.name).set\(Source.inline(angled: function.parameters))(\(name):)
                    """
                    if let modifiers:String = modifiers 
                    {
                        """
                        /// \(modifiers)
                        """
                    }
                    """
                    /// where \(function.constraints.joined(separator: ", "))
                    ///     Sets this delegate’s [`\(name)`] property to the given value. 
                    /// - value :\(function.range.outer)
                    /// #   [See also](\(tag))
                    /// #   (0:\(host.tag("property", "accessors")))
                    /// #   (\(tag))
                    """
                    if let modifiers:String = modifiers 
                    {
                        modifiers
                    }
                    """
                    func set\(Source.inline(angled: function.parameters))\
                    (\(name != "value" ? "\(name) " : "")value:\(function.range.outer)) \
                    \(Source.constraints(function.constraints))
                    """
                    set
                }
            }
        }
    } 
}
extension Godot.Class.Node.Method 
{
    func define(as name:String, originally symbol:String, in host:Godot.Class.Node) -> String 
    {
        let function:Godot.Function 
        switch self.result 
        {
        case .thrown:
            function = .init(domain: self.parameters.map(\.type), range: .void)
        case .returned(let type):
            function = .init(domain: self.parameters.map(\.type), range: type)
        }
        
        let arguments:[(label:String, name:String?, type:Godot.Function.Scalar)] = 
            zip(self.parameters.map
            {
                (label: $0.label, name: $0.label == $0.name ? nil : $0.name)
            }, function.domain)
            .map
            {
                (element:(argument:(label:String, name:String?), type:Godot.Function.Scalar)) in
                (
                    label:  element.argument.label, 
                    name:   element.argument.name, 
                    type:   element.type 
                )
            }
        
        let expressions:[String] = ["self: self"] + arguments.map 
        {
            $0.type.inner(expression: $0.name ?? $0.label)
        }
        let signature:(generics:String, domain:String) = 
        (
            Source.inline(angled: function.parameters, else: ""), 
            Source.inline(list: arguments.map
            { 
                "\($0.label)\($0.name.map{ " \($0)" } ?? ""):\($0.type.outer)" 
            }
            +
            (function.metatype.map 
            {
                ["as _:\($0).Type"]
            } ?? []))
        )
        let modifiers:String? 
        switch (self.is.final, self.is.override)
        {
        case (true , false):    modifiers = "final"
        case (true , true ):    modifiers = "final override"
        case (false, true ):    modifiers = "override"
        case (false, false):    modifiers = nil 
        }
        return Source.fragment 
        {
            // emit doccomment 
            """
            /// func \(host.namespace).\(host.name).\(name)\(signature.generics)\
            (\((arguments.map
            { 
                "\($0.label):" 
            }
            + 
            (function.metatype == nil ? [] : ["as:"]))
            .joined())) \(self.result == .thrown ? "throws" : "")
            """
            if let modifiers:String = modifiers 
            {
                """
                /// \(modifiers)
                """
            }
            if !function.constraints.isEmpty
            {
                """
                /// where \(function.constraints.joined(separator: ", "))
                """
            }
            """
            ///     The [`\(symbol)`](\(host.url)#class-\(host.symbol.lowercased())-method-\(String.init(symbol.map 
            {
                $0 == "_" ? "-" : $0
            }))) instance method.
            """
            // specific remarks 
            if host.name == ["Any", "Delegate"], symbol == "is_class"
            {
                """
                /// 
                ///     All Godot classes are bridged to the Swift type system, 
                ///     which means you can query the dynamic type of class 
                ///     instances, including Godot delegates, using the 
                ///     [`is`](https://docs.swift.org/swift-book/LanguageGuide/TypeCasting.html)  
                ///     and [`as`](https://docs.swift.org/swift-book/LanguageGuide/TypeCasting.html) 
                ///     operators.
                ///     
                ///     Only use this method if you need to query the dynamic 
                ///     type of a Godot delegate by string name.
                """
            }
            for (label, name, type):(String, String?, Godot.Function.Scalar) in arguments
            {
                """
                /// - \(name ?? label):\(type.outer)
                """
            }
            if let metatype:String = function.metatype 
            {
                """
                /// - _:\(metatype).Type
                """
            }
            if case .concrete(type: "Void") = function.range 
            {
            }
            else 
            {
                """
                /// - ->:\(function.range.outer)
                """
            }
            
            if let modifiers:String = modifiers 
            {
                modifiers
            }
            switch (self.result, function.range)
            {
            case (.thrown, _):
                """
                func \(name)\(signature.generics)\(signature.domain) throws \
                \(Source.constraints(function.constraints))
                {
                    let status:Int64 = Godot.Functions.\(host.name).\(name)\(Source.inline(list: expressions))
                    guard status == 0 
                    else 
                    {
                        throw Godot.Error.init(value: Int.init(status))
                    }
                }
                """
            case (_, .concrete(type: "Void")):
                """
                func \(name)\(signature.generics)\(signature.domain) \
                \(Source.constraints(function.constraints))
                {
                    Godot.Functions.\(host.name).\(name)\(Source.inline(list: expressions))
                }
                """
            case (_, let range):
                """
                func \(name)\(signature.generics)\(signature.domain) -> \(range.outer) \
                \(Source.constraints(function.constraints))
                {
                    let result:\(range.inner) = Godot.Functions.\(host.name).\(name)\(Source.inline(list: expressions))
                    return \(range.outer(expression: "result"))
                }
                """
            }
        }
    } 
}

extension Godot 
{
    enum KnownType:Hashable 
    {
        case void 
        case bool 
        case int 
        case float 
        case vector2
        case vector3
        case vector4
        
        case quaternion 
        case plane3
        case rectangle2 
        case rectangle3
        case affine2 
        case affine3
        case linear3
        case resourceIdentifier
        
        case list 
        case map 
        case nodePath
        case string 
        
        case uint8Array
        case int32Array
        case float32Array
        case stringArray
        case vector2Array
        case vector3Array
        case vector4Array
        
        case object(String)
        case enumeration(String)
        
        case variant
    }
    
    struct Function
    {
        enum Convention 
        {
            case variant 
            case enumeration(String)
            case concrete   (String)
            case generic    (String, as:String, (String) -> String, constraints:(String) -> String)
        }
        
        enum Scalar 
        {
            case variant 
            case enumeration(type:String)
            case concrete   (type:String)
            case generic    (type:String, as:String)
        }
        
        let domain:[Scalar]
        let range:Scalar
        let metatype:String?
        
        let parameters:[String]
        let constraints:[String]
    }
}
extension Godot.Function.Convention
{
    init(_ type:Godot.KnownType)
    {
        switch type 
        {
        case .void:
            self =  .concrete("Void")
        case .bool:
            self =  .concrete("Bool")
        case .int:
            self =  .generic("T", as: "Int64"){ $0 } 
            constraints:    { "\($0):FixedWidthInteger" }
        case .float:
            self =  .generic("T", as: "Float64"){ $0 }
            constraints:    { "\($0):BinaryFloatingPoint" }
        case .vector2:
            self =  .generic("T", as: "Float32"){ "Vector2<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .vector3:
            self =  .generic("T", as: "Float32"){ "Vector3<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .vector4:
            self =  .generic("T", as: "Float32"){ "Vector4<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        
        case .rectangle2:
            self =  .generic("T", as: "Float32"){ "Vector2<\($0)>.Rectangle" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .rectangle3:
            self =  .generic("T", as: "Float32"){ "Vector3<\($0)>.Rectangle" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        
        case .quaternion:
            self =  .generic("T", as: "Float32"){ "Quaternion<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & Numerics.Real & SIMDScalar" }
        case .plane3:
            self =  .generic("T", as: "Float32"){ "Plane3<\($0)>" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }

        case .affine2:
            self =  .generic("T", as: "Float32"){ "Transform2<\($0)>.Affine" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .affine3:
            self =  .generic("T", as: "Float32"){ "Transform3<\($0)>.Affine" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .linear3:
            self =  .generic("T", as: "Float32"){ "Transform3<\($0)>.Linear" }
            constraints:    { "\($0):BinaryFloatingPoint & SIMDScalar" }
        case .resourceIdentifier:   
            self =  .concrete("ResourceIdentifier")
        
        case .list:
            self =  .concrete("List")
        case .map:
            self =  .concrete("Map")
        case .nodePath:
            self =  .concrete("NodePath")
        case .string:               
            self =  .generic("S", as: "Godot.String") { $0 }
            constraints:    { "\($0):StringRepresentable" }
        
        case .uint8Array:
            self =  .generic("S", as: "Godot.Array<UInt8>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == UInt8" }
        case .int32Array:
            self =  .generic("S", as: "Godot.Array<Int32>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == Int32" }
        case .float32Array:
            self =  .generic("S", as: "Godot.Array<Float32>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == Float32" }
        case .stringArray:
            self =  .generic("S", as: "Godot.Array<Swift.String>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == Swift.String" }
        case .vector2Array:
            self =  .generic("S", as: "Godot.Array<Vector2<Float32>>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == Vector2<Float32>" }
        case .vector3Array:
            self =  .generic("S", as: "Godot.Array<Vector3<Float32>>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == Vector3<Float32>" }
        case .vector4Array:
            self =  .generic("S", as: "Godot.Array<Vector4<Float32>>"){ $0 }
            constraints:    { "\($0):ArrayRepresentable, \($0).Element == Vector4<Float32>" }
        case .object(let type): 
            self =  .concrete("\(type)?")
        case .enumeration(let type):
            self =  .enumeration(type)
        case .variant:
            self =  .variant
        }
    }
}
extension Godot.Function 
{
    init(domain:[Godot.KnownType], range:Godot.KnownType)
    {
        let conventions:[Convention]    = (domain + [range]).map(Convention.init(_:))
        // find out how many generics of each letter we are going to need 
        let multiplicity:[String: Int]  = .init(conventions.compactMap 
            {
                if case .generic(let prefix, as: _, _, constraints: _) = $0 
                {
                    return (prefix, 1)
                }
                else 
                {
                    return nil
                }
            }, 
            uniquingKeysWith: + )
        // initialize arrays and counters for any letters that appear more than once 
        var constraints:[String]    = [], 
            parameters:[String]     = [], 
            scalars:[Scalar]        = [], 
            counter:[String: Int]   = multiplicity.compactMapValues 
        {
            $0 > 1 ? 0 : nil
        }
        
        for convention:Convention in conventions
        {
            let scalar:Scalar 
            switch convention 
            {
            case .variant: 
                scalar = .variant 
            case .enumeration(let type):
                scalar = .enumeration(type: type)
            case .concrete(let type):
                scalar = .concrete(type: type)
            case .generic(let prefix, as: let argument, let type, constraints: let constraint):
                let parameter:String
                if let index:Dictionary<String, Int>.Index = counter.index(forKey: prefix)
                {
                    parameter               = "\(prefix)\(counter.values[index])"
                    counter.values[index]  += 1
                }
                else 
                {
                    parameter               = prefix 
                }
                
                constraints.append(constraint(parameter))
                parameters.append(parameter)
                
                scalar = .generic(type: type(parameter), as: type(argument))
            }
            scalars.append(scalar)
        }
        
        self.parameters     = parameters 
        self.constraints    = constraints 
        
        self.range          = scalars.removeLast() 
        self.domain         = scalars
        // if the return type is generic, *and none of the arguments* use that 
        // type, add an `as:` metatype argument 
        if  case .generic(type: let type, as: _) = self.range, 
            (self.domain.allSatisfy
            {
                switch $0 
                {
                case .generic(type: type, as: _):
                    return false 
                default: 
                    return true 
                }
            })
        {
            self.metatype = type 
        }
        else 
        {
            self.metatype = nil
        }
    }
}
extension Godot.Function.Scalar 
{
    var canonical:String
    {
        switch self 
        {
        case    .variant: 
            return "Godot.Variant?"
        case    .enumeration(type:        let type), 
                .concrete   (type:        let type),
                .generic    (type: _, as: let type):
            return type 
        } 
    } 
    var outer:String 
    {
        switch self 
        {
        case    .variant: 
            return "Godot.Variant?"
        case    .enumeration(type: let type), 
                .concrete   (type: let type),
                .generic    (type: let type, as: _):
            return type 
        }
    }
    var inner:String 
    {
        switch self 
        {
        case    .variant: 
            return "Godot.VariantExistential"
        case    .enumeration(type: _):
            return "Int64" 
        case    .concrete   (type:        let type),
                .generic    (type: _, as: let type):
            return type 
        }
    }
    func inner(expression:String) -> String 
    {
        switch self 
        {
        case .variant:
            return "Godot.VariantExistential.init(variant: \(expression))"
        case .enumeration:
            return                             "Int64.init(\(expression).value)"
        case .concrete: 
            return                                           expression
        case .generic(type: _, as: let type):
            return                           "\(type).init(\(expression))"
        }
    }
    func outer(expression:String) -> String 
    {
        switch self 
        {
        case .variant:
            return                               "\(expression).variant"
        case .enumeration   (type: let type):
            return  "\(type).init(value: Int.init(\(expression)))"
        case .concrete: 
            return                                  expression
        case .generic       (type: let type, as: _):
            return                  "\(type).init(\(expression))"
        }
    }
}
