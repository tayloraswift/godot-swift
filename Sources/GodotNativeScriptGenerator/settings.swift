import TSCBasic

struct Settings:Codable 
{
    let updateInterface:Bool 
    
    enum CodingKeys:String, CodingKey 
    {
        case updateInterface    = "update_interface"
    }
}
extension Settings:CustomStringConvertible 
{
    var description:String
    {
        """
        {
            update interface: \(self.updateInterface)
        }
        """
    }
}
extension Settings 
{
    private static 
    var `default`:Self
    {
        let settings:Self = .init(updateInterface: true)
        print(note: "using default plugin settings:")
        print(settings)
        return settings 
    }
    static 
    func load(from path:AbsolutePath) -> Self 
    {
        guard let string:String = try? 
            TSCBasic.localFileSystem.readFileContents(path).description
        else 
        {
            print(warning:  "could not open godot nativescript settings file")
            print(note:     "from '\(path)'")
            return .default 
        }
        guard   let json:JSON     =      .init(parsing: string), 
                let settings:Self = try? .init(from: JSON.Decoder.init(json: json))
        else 
        {
            print(warning:  "could not parse godot nativescript settings file")
            print(note:     "from '\(path)'")
            return .default 
        }
        print(note: "using plugin settings:")
        print(settings)
        return settings 
    }
}
