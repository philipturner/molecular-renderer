// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "MolecularRenderer",
  platforms: [
    .macOS(.v13),
  ],
  products: [
    .library(
      name: "COpenMM",
      targets: ["COpenMM"]),
    .library(
      name: "Hardware",
      targets: ["Hardware"]),
    .library(
      name: "HDL",
      targets: ["HDL"]),
    .library(
      name: "MolecularRenderer",
      targets: ["MolecularRenderer"]),
    .library(
      name: "OpenMM",
      targets: ["OpenMM"]),
  ],
  dependencies: [
    .package(url: "https://github.com/philipturner/applegpuinfo", from: "2.0.1"),
  ],
  targets: [
    .target(
      name: "COpenMM",
      dependencies: []),
    .target(
      name: "Hardware",
      dependencies: ["HDL"]),
    .target(
      name: "HDL",
      dependencies: []),
    .target(
      name: "MolecularRenderer",
      dependencies: []),
    .target(
      name: "OpenMM",
      dependencies: ["COpenMM"]),
  ]
)
