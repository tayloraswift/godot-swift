import PackagePlugin

@main struct GodotNativeScriptPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let tool = try context.tool(named: "GodotNativeScriptGenerator")
        let directory = context.pluginWorkDirectory
//        let sources: [Path] = context.inputFiles.filter { $0.type == .source }.map(\.path)
        
        print("Hello")
        print(directory.string)
        
        let sources: [Path] = []

        let output: (staged: Path, common: Path, classes: Path) =
            (
                directory.appending("registration.swift"),
                directory.appending("common.swift"),
                directory.appending("classes.swift")
            )

        return [
            .buildCommand(
                displayName: "Generating files '\(output.common)', '\(output.classes)'",
                executable: tool.path,
                arguments: [
                    "generate",
                    "--output-common", "\(output.common)",
                    "--output-classes", "\(output.classes)",
                ],
                inputFiles: sources,
                outputFiles: [
                    output.common,
                    output.classes,
                ]
            ),
            .buildCommand(
                displayName: "Generating file '\(output.staged)'",
                executable: tool.path,
                arguments: [
                    "synthesize",
                    "--workspace", "\(directory)",
                    "--output", "\(output.staged)",
                    "--target", target.name,
                    "--package-path", "\(context.package.directory.string)",
                ],
                inputFiles: sources,
                outputFiles: [output.staged]
            ),
        ]
    }
}
