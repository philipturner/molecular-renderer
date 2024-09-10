// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "molecular-renderer",
  products: [
    .library(
      name: "MolecularRenderer",
      targets: ["MolecularRenderer"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/philipturner/HDL",
      branch: "main"),
    .package(
      url: "https://github.com/philipturner/swift-numerics",
      branch: "Quaternions"),
  ],
  targets: [
    .executableTarget(
      name: "Workspace",
      dependencies: [
        .product(name: "HDL", package: "HDL"),
        "MolecularRenderer",
        .product(name: "Numerics", package: "swift-numerics"),
      ]),
    .target(
      name: "MolecularRenderer",
      dependencies: []),
  ]
)
