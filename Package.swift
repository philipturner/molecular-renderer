// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "molecular-renderer",
  products: [
    .library(
      name: "MolecularRenderer",
      targets: ["MolecularRenderer"]),
  ],
  targets: [
    .executableTarget(
      name: "Workspace",
      dependencies: [
        "MolecularRenderer"
      ]),
    .target(
      name: "MolecularRenderer",
      dependencies: []),
  ]
)
