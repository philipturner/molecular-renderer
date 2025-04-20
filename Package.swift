// swift-tools-version: 6.1

import PackageDescription

// MARK: - Inter-Module Dependencies

// These dependencies are likely platform-specific.
var rendererDependencies: [Target.Dependency] = []

// These are all the libraries to link to the Workspace executable.
var workspaceDependencies: [Target.Dependency] = []

workspaceDependencies += [
  .product(name: "Atomics", package: "swift-atomics"),
  .product(name: "Numerics", package: "swift-numerics"),
  "MolecularRenderer"
]

#if os(Windows)
workspaceDependencies += [
  "DXCompiler",
  "FidelityFX",
  .product(name: "SwiftCOM", package: "swift-com"),
]
#endif

// MARK: - Common Targets

var dependencies: [Package.Dependency] = []
var targets: [Target] = []

dependencies.append(.package(
  url: "https://github.com/apple/swift-atomics",
  .upToNextMajor(from: "1.2.0")))

dependencies.append(.package(
  url: "https://github.com/philipturner/swift-numerics",
  branch: "Quaternions"))

targets.append(.target(
  name: "MolecularRenderer",
  dependencies: rendererDependencies))

targets.append(.executableTarget(
  name: "Workspace",
  dependencies: workspaceDependencies))

// MARK: - Windows Targets

#if os(Windows)
dependencies.append(.package(
  url: "https://github.com/philipturner/swift-com",
  branch: "main"))

targets.append(.target(
  name: "CDXCompiler",
  dependencies: [],
  linkerSettings: [
    .linkedLibrary("dxcompiler"),
  ]))

targets.append(.target(
  name: "DXCompiler",
  dependencies: [
    "CDXCompiler",
    .product(name: "SwiftCOM", package: "swift-com"),
  ]))

targets.append(.target(
  name: "FidelityFX",
  dependencies: [],
  linkerSettings: [
    // .linkedLibrary("amd_fidelityfx_dx12"),
  ]))
#endif

// MARK: - Package

let package = Package(
  name: "molecular-renderer",
  platforms: [.macOS(.v15)],
  dependencies: dependencies,
  targets: targets)
