// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MolecularRenderer",
  platforms: [
    .macOS(.v14),
    .iOS(.v17),
  ],
  products: [
    .library(
      name: "MolecularRenderer",
      targets: ["MolecularRenderer"]),
  ],
  dependencies: [],
  targets: [
    .target(
      name: "MolecularRenderer",
      dependencies: []),
  ]
)
