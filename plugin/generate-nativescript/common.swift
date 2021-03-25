import struct TSCBasic.AbsolutePath

enum Synthesizer 
{
    static 
    func generate(common:AbsolutePath)
    {
        Source.generate(file: common)
        {
            Vector.swift 
        }
    }
}
