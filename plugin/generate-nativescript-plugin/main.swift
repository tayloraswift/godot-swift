import PackagePlugin

let sources:[Path]  = targetBuildContext.sourceFiles 
let directory:Path  = targetBuildContext.outputDir

let output:(common:Path, staged:Path) = 
(
    directory.appending("common.swift"),
    directory.appending("registration.swift")
)

commandConstructor.createCommand(
    displayName:
        "Generating files '\(output.common)', '\(output.staged)'",
    executable:
        try targetBuildContext.lookupTool(named: "GenerateNativeScript"),
    arguments: 
    [
        "--workspace",      "\(directory)", 
        "--output-common",  "\(output.common)", 
        "--output-staged",  "\(output.staged)", 
        "--target",         targetBuildContext.targetName,
        "--package-path",   "\(targetBuildContext.packageDir)"
    ],
    inputPaths: sources,
    outputPaths: 
    [
        output.common,
        output.staged,
    ]
)

commandConstructor.addGeneratedOutputFile(path: output.common)
commandConstructor.addGeneratedOutputFile(path: output.staged)
