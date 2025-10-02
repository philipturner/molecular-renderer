// swift-tools-version: 6.1

import PackageDescription
import class Foundation.ProcessInfo
 
// MARK: - Inter-Module Dependencies

// These dependencies are likely platform-specific.
var rendererDependencies: [Target.Dependency] = []
var rendererLinkerSettings: [LinkerSetting] = []

// These are all the libraries to link to the Workspace executable.
var workspaceDependencies: [Target.Dependency] = []
var workspaceLinkerSettings: [LinkerSetting] = []

// Common dependencies.
workspaceDependencies += [
  .product(name: "Atomics", package: "swift-atomics"),
  .product(name: "HDL", package: "HDL"),
  .product(name: "Numerics", package: "swift-numerics"),
  "MolecularRenderer",
  .product(name: "OpenMM", package: "swift-openmm"),
]
//workspaceLinkerSettings += [
//  .linkedLibrary("OpenMM"),
//]
#if os(macOS)
//let repoDirectory = Context.packageDirectory
//workspaceLinkerSettings += [
//  .unsafeFlags(["-L\(repoDirectory)"])
//]

//if let path = ProcessInfo.processInfo.environment["REPO_DIRECTORY"] {
//  workspaceLinkerSettings += [
//    .unsafeFlags(["-L\(path)"]),
//  ]
//}
#endif
if let path = ProcessInfo.processInfo.environment["OPENMM_LIBRARY_PATH"] {
  workspaceLinkerSettings += [
    .unsafeFlags(["-L\(path)"]),
    .linkedLibrary("OpenMM"),
  ]
}

// Windows dependencies.
#if os(Windows)
rendererDependencies += [
  "FidelityFX",
  .product(name: "SwiftCOM", package: "swift-com"),
]
rendererLinkerSettings.append(
  .linkedLibrary("dxcompiler_wrapper"))
#endif

// MARK: - Common Targets

var targets: [Target] = []
targets.append(.target(
  name: "MolecularRenderer",
  dependencies: rendererDependencies,
  linkerSettings: rendererLinkerSettings))

targets.append(.executableTarget(
  name: "Workspace",
  dependencies: workspaceDependencies,
  linkerSettings: workspaceLinkerSettings))

var packageDependencies: [Package.Dependency] = []

// Non-simulator dependencies

packageDependencies.append(.package(
  url: "https://github.com/apple/swift-atomics",
  .upToNextMajor(from: "1.3.0")))

packageDependencies.append(.package(
  url: "https://github.com/philipturner/HDL",
  branch: "main"))

packageDependencies.append(.package(
  url: "https://github.com/philipturner/swift-numerics",
  branch: "Quaternions"))

// Simulator dependencies

packageDependencies.append(.package(
  url: "https://github.com/philipturner/swift-openmm",
  branch: "main"))

// MARK: - Windows Targets

// Strange: once you add binary dependences, the 'Workspace' executable stops
// working correctly when you call 'swift run' from Git Bash. But it works just
// fine when you call 'swift run' from inside the terminal in VSCode. The
// terminal inside VSCode can be annoying, because it keeps refreshing when you
// make any changes to the code. Nonetheless, it's workable.
//
// WARNING: Do not launch the application from Git Bash on Windows.
//
// The problem may have been fixed by migrating the raw binary dependencies to
// the 'MolecularRenderer' module. I have not tested this hypothesis, and am
// sticking with the guidance above.

#if os(Windows)
packageDependencies.append(.package(
  url: "https://github.com/philipturner/swift-com",
  branch: "main"))

targets.append(.target(
  name: "FidelityFX",
  dependencies: [],
  linkerSettings: [
    .linkedLibrary("amd_fidelityfx_upscaler_dx12"),
  ]))
#endif

// MARK: - Package

let package = Package(
  name: "molecular-renderer",
  platforms: [.macOS(.v15)],
  dependencies: packageDependencies,
  targets: targets)
