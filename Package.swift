// swift-tools-version: 5.10

import PackageDescription

let package = Package(
  name: "molecular-renderer",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(
      name: "MolecularRenderer",
      targets: ["MolecularRenderer"]),
  ],
  dependencies: [
    .package(
      url: "https://github.com/apple/swift-atomics",
      .upToNextMajor(from: "1.2.0")),
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
        .product(name: "Atomics", package: "swift-atomics"),
        .product(name: "HDL", package: "HDL"),
        "MolecularRenderer",
        .product(name: "Numerics", package: "swift-numerics"),
      ]),
    .target(
      name: "MolecularRenderer",
      dependencies: []),
  ]
)
