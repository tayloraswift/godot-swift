import PackagePlugin

let tool:TargetBuildContext.Tool = try targetBuildContext.tool(named: "GodotNativeScriptGenerator")
let directory:Path  = targetBuildContext.outputDirectory
let sources:[Path]  = targetBuildContext.inputFiles.filter
{
    $0.type == .source
}
.map(\.path)

let output:(staged:Path, common:Path, classes:Path) = 
(
    directory.appending("registration.swift"),
    directory.appending("common.swift"),
    directory.appending("classes.swift")
)

commandConstructor.createBuildCommand(
    displayName:
        "Generating files '\(output.common)', '\(output.staged)'",
    executable: tool.path,
    arguments: 
    [
        "--workspace",      "\(directory)", 
        "--output-staged",  "\(output.staged)", 
        "--output-common",  "\(output.common)", 
        "--output-classes", "\(output.classes)", 
        "--target",            targetBuildContext.targetName,
        "--package-path",   "\(targetBuildContext.packageDirectory)"
    ],
    inputFiles: sources,
    outputFiles: 
    [
        output.staged,
        output.common,
        output.classes,
    ]
)
