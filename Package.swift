// swift-tools-version: 6.1

import PackageDescription
 
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
  .product(name: "Numerics", package: "swift-numerics"),
  "MolecularRenderer"
]

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

var dependencies: [Package.Dependency] = []
var targets: [Target] = []

dependencies.append(.package(
  url: "https://github.com/apple/swift-atomics",
  .upToNextMajor(from: "1.3.0")))

dependencies.append(.package(
  url: "https://github.com/philipturner/swift-numerics",
  branch: "Quaternions"))

targets.append(.target(
  name: "MolecularRenderer",
  dependencies: rendererDependencies,
  linkerSettings: rendererLinkerSettings))

targets.append(.executableTarget(
  name: "Workspace",
  dependencies: workspaceDependencies,
  linkerSettings: workspaceLinkerSettings))

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
dependencies.append(.package(
  url: "https://github.com/philipturner/swift-com",
  branch: "main"))

targets.append(.target(
  name: "FidelityFX",
  dependencies: [],
  linkerSettings: [
    .linkedLibrary("amd_fidelityfx_dx12"),
  ]))
#endif

// MARK: - Package

let package = Package(
  name: "molecular-renderer",
  platforms: [.macOS(.v15)],
  dependencies: dependencies,
  targets: targets)
