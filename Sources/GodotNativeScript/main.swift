import PackagePlugin

let tool:TargetBuildContext.Tool = try targetBuildContext.tool(named: "GodotNativeScriptGenerator")
let directory:Path  = targetBuildContext.outputDirectory
let sources:[Path]  = targetBuildContext.inputFiles.filter
{
    $0.type == .source
}
.map(\.path)

let output:(common:Path, staged:Path) = 
(
    directory.appending("common.swift"),
    directory.appending("registration.swift")
)

commandConstructor.createBuildCommand(
    displayName:
        "Generating files '\(output.common)', '\(output.staged)'",
    executable: tool.path,
    arguments: 
    [
        "--workspace",      "\(directory)", 
        "--output-common",  "\(output.common)", 
        "--output-staged",  "\(output.staged)", 
        "--target",            targetBuildContext.targetName,
        "--package-path",   "\(targetBuildContext.packageDirectory)"
    ],
    inputFiles: sources,
    outputFiles: 
    [
        output.common,
        output.staged,
    ]
)
