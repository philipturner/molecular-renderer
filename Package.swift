// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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
    name: "OpenMM",
    targets: ["OpenMM"]),
]
var targets: [Target] = [
  .target(
    name: "COpenMM",
    dependencies: []),
  .target(
    name: "HardwareCatalog",
    dependencies: ["HDL"]),
  .target(
    name: "HDL",
    dependencies: []),
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
  dependencies: [],
  targets: targets
)
