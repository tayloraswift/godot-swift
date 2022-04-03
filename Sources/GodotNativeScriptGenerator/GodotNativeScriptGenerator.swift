//
//  File.swift
//
//
//  Created by KyleYe on 2022/4/3.
//

import ArgumentParser
import TSCBasic
import Foundation

@main
struct GodotNativeScriptGenerator: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Generate code for godot-swift.",
        subcommands: [Generator.self, Synthesizer.self],
        defaultSubcommand: Generator.self)
}

extension AbsolutePath: ExpressibleByArgument {
    public init?(argument string: String) {
        if let base = localFileSystem.currentWorkingDirectory {
            self.init(string, relativeTo: base)
        } else {
            try? self.init(validating: string)
        }
    }
}
