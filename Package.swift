// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import class Foundation.ProcessInfo

var platforms: [SupportedPlatform]? = nil
var products: [Product] = [
  .library(
    name: "HardwareCatalog",
    targets: ["HardwareCatalog"]),
  .library(
    name: "HDL",
    targets: ["HDL"]),
]
var targets: [Target] = [
  .target(
    name: "HardwareCatalog",
    dependencies: [
      "HDL",
      .product(name: "MM4", package: "MM4")
    ]),
  .target(
    name: "HDL",
    dependencies: [
      .product(name: "QuaternionModule", package: "swift-numerics"),
    ]),
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
    .package(url: "https://github.com/philipturner/swift-openmm", branch: "main"),
    .package(url: "https://github.com/philipturner/MM4", branch: "main")
  ],
  targets: targets
)
