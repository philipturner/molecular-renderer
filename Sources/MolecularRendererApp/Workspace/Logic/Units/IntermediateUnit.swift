//
//  IntermediateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/12/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct IntermediateUnit {
  var propagate: [Rod]
  var generate: [Rod]
  var driveWall: DriveWall
  
  var holePatterns: [HolePattern] = []
  var rods: [Rod] {
    var output: [Rod] = []
    output.append(contentsOf: propagate)
    output.append(contentsOf: generate)
    return output
  }
  
  init() {
    // Create the source rod.
    var boundsSet: [SIMD2<Float>] = []
    boundsSet.append(SIMD2(2, 6))
    boundsSet.append(SIMD2(10, 14))
    boundsSet.append(SIMD2(16, 20))
    
    let lattice = Self.createLattice(boundsSet: boundsSet)
    var rod = Rod(lattice: lattice)
    rod.rigidBody.rotate(angle: -.pi, axis: [0, 1, 0])
    do {
      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
      var center = rod.rigidBody.centerOfMass
      center = SIMD3(-center.x, center.y, center.z)
      center.x += 22 * latticeConstant
      rod.rigidBody.centerOfMass = center
    }
    
    // Create the logic rods.
    var holeOffsets: [SIMD3<Float>] = []
    
    do {
      var offset = SIMD3<Float>(0, 2.75 + 0.5, 0.5)
      var source = rod
      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      propagate = Self.createLayers(source: source)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0, 2.75 + 0.5, 0.5 + 6)
      var source = rod
      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      generate = Self.createLayers(source: source)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsets.append(offset)
    }
    
    // Create the hole patterns.
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = 6 * Float(layerID)
        holePatterns.append(
          Self.createHolePattern(offset: SIMD3(0, y, 0) + offset))
      }
    }
    
    // Create the ramp patterns.
    var rampPatterns: [RampPattern] = []
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = -3.25 + 6 * Float(layerID)
        rampPatterns.append(
          Self.createRampPattern(offset: SIMD3(22, y, 0) + offset))
      }
    }
    driveWall = Self.createDriveWall(patterns: rampPatterns)
  }
}

// MARK: - Rods

extension IntermediateUnit {
  // Create a lattice for a logic rod.
  static func createLattice(boundsSet: [SIMD2<Float>]) -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 32 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        let pattern = Self.createDriveWallInterface()
        pattern(h, h2k, l)
      }
      
      for bounds in boundsSet {
        let pattern = Self.createKnobPattern(bounds: bounds)
        Volume {
          pattern(h, h2k, l)
        }
      }
    }
  }
  
  // Create an interface to the drive wall.
  static func createDriveWallInterface() -> KnobPattern {
    return { h, h2k, l in
      Concave {
        Concave {
          Origin { 1 * h2k }
          Plane { h2k }
          Origin { 1 * h }
          Plane { h2k - 3 * h } // k - h
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
          Origin { 0.5 * h }
          Plane { -h }
        }
      }
      Replace { .empty }
    }
  }
  
  // Accepts bounds in multiples of the cubic diamond lattice constant.
  static func createKnobPattern(bounds: SIMD2<Float>) -> KnobPattern {
    let cubicConstant = Constant(.square) { .elemental(.carbon) }
    let hexagonalConstant = Constant(.hexagon) { .elemental(.carbon) }
    let shrunkBounds = bounds + SIMD2(0.125, -0.125)
    let scaledBounds = shrunkBounds * cubicConstant / hexagonalConstant
    
    return { h, h2k, l in
      Concave {
        Concave {
          Origin { scaledBounds[0].rounded(.down) * h }
          Plane { h }
        }
        Concave {
          Origin { 0.5 * h2k }
          Plane { -h2k }
        }
        Concave {
          Origin { scaledBounds[1].rounded(.up) * h }
          Plane { -h }
        }
      }
      Replace { .empty }
    }
  }
  
  // Spawns the logic rods for all Y layers, from a single source rod.
  static func createLayers(source: Rod) -> [Rod] {
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let spacing = 6 * latticeConstant
    
    var output: [Rod] = []
    for layerID in 0..<2 {
      var rod = source
      rod.rigidBody.centerOfMass.y += spacing * Double(layerID)
      output.append(rod)
    }
    return output
  }
}

// MARK: - Housing

extension IntermediateUnit {
  static func createHolePattern(offset: SIMD3<Float>) -> HolePattern {
    { h, k, l in
      Origin { offset[0] * h + offset[1] * k + offset[2] * l }
      
      Concave {
        Concave {
          Plane { k }
          Plane { l }
        }
        Concave {
          Origin { 4.25 * k + 4 * l }
          Plane { -k }
          Plane { -l }
        }
      }
      
      Replace { .empty }
    }
  }

  static func createRampPattern(offset: SIMD3<Float>) -> RampPattern {
    { h, k, l in
      Origin { offset[0] * h + offset[1] * k + offset[2] * l }
      
      Concave {
        Concave {
          Plane { k }
          Plane { l }
        }
        Concave {
          Origin { 4 * l }
          Plane { -l }
        }
        Concave {
          Plane { -h - k }
          Origin { 2 * -h }
          Plane { -h }
        }
      }
      
      Replace { .empty }
    }
  }
  
  static func createDriveWall(patterns: [RampPattern]) -> DriveWall {
    var driveWallDesc = DriveWallDescriptor()
    driveWallDesc.dimensions = SIMD3(22, 17, 14)
    driveWallDesc.patterns = patterns
    driveWallDesc.patterns.append { h, k, l in
      Origin { (22 - 5.5) * h }
      Plane { -h }
      Replace { .empty }
    }
    driveWallDesc.patterns.append { h, k, l in
      Origin { (22 - 1) * h }
      Plane { h }
      Replace { .empty }
    }
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    var driveWall = DriveWall(descriptor: driveWallDesc)
    driveWall.rigidBody.centerOfMass.x += (5.5 + 1) * latticeConstant
    return driveWall
  }
}
