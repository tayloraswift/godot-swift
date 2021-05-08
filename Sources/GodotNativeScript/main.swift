import PackagePlugin

let tool:TargetBuildContext.Tool = 
    try targetBuildContext.tool(named: "GodotNativeScriptGenerator")
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
        "Generating files '\(output.common)', '\(output.classes)'",
    executable: tool.path,
    arguments: 
    [
        "generate",
        
        "--output-common",  "\(output.common)", 
        "--output-classes", "\(output.classes)", 
    ],
    inputFiles: sources,
    outputFiles: 
    [
        output.common,
        output.classes,
    ]
)
commandConstructor.createBuildCommand(
    displayName:
        "Generating file '\(output.staged)'",
    executable: tool.path,
    arguments: 
    [
        "synthesize",
        
        "--workspace",      "\(directory)", 
        "--output",         "\(output.staged)", 
        "--target",            targetBuildContext.targetName,
        "--package-path",   "\(targetBuildContext.packageDirectory)"
    ],
    inputFiles: sources,
    outputFiles: 
    [
        output.staged,
    ]
)
