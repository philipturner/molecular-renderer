// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import class Foundation.ProcessInfo

var linkerSettings: [LinkerSetting] = []

// Example: "/Users/philipturner/miniforge3/lib"
if let path = ProcessInfo.processInfo.environment["OPENMM_LIBRARY_PATH"] {
  linkerSettings = [
    .unsafeFlags(["-L\(path)"]),
    .linkedLibrary("OpenMM"),
  ]
}

var platforms: [SupportedPlatform]? = nil
var products: [Product] = [
  .library(
    name: "COpenMM",
    targets: ["COpenMM"]),
  .library(
    name: "HardwareCatalog",
    targets: ["HardwareCatalog"]),
  .library(
    name: "HDL",
    targets: ["HDL"]),
  .library(
    name: "MM4",
    targets: ["MM4"]),
  .library(
    name: "OpenMM",
    targets: ["OpenMM"]),
]
var targets: [Target] = [
  .target(
    name: "COpenMM",
    dependencies: []),
  .target(
    name: "HardwareCatalog",
    dependencies: ["HDL", "MM4"]),
  .target(
    name: "HDL",
    dependencies: [
      .product(name: "QuaternionModule", package: "swift-numerics"),
    ]),
  .target(
    name: "MM4",
    dependencies: ["OpenMM"]),
  .testTarget(
    name: "MM4Tests",
    dependencies: ["MM4"],
    linkerSettings: linkerSettings),
  .target(
    name: "OpenMM",
    dependencies: ["COpenMM"]),
]

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
platforms = [
  .macOS(.v13)
]
products += [
  .library(
    name: "MolecularRenderer",
    targets: ["MolecularRenderer"]),
]
targets += [
  .target(
    name: "MolecularRenderer",
    dependencies: []),
]
#endif

let package = Package(
  name: "MolecularRenderer",
  platforms: platforms,
  products: products,
  dependencies: [
    .package(url: "https://github.com/apple/swift-numerics", branch: "Quaternions"),
    .package(url: "https://github.com/iwill/generic-json-swift", branch: "master")
  ],
  targets: targets
)
