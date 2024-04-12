//
//  InputUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/12/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct InputUnit {
  var operandA: [Rod]
  var operandB: [Rod]
  var sum: [Rod]
  var operandDriveWall: DriveWall
  var sumDriveWall: DriveWall
  
  var holePatterns: [HolePattern] = []
  var rods: [Rod] {
    var output: [Rod] = []
    output.append(contentsOf: operandA)
    output.append(contentsOf: operandB)
    output.append(contentsOf: sum)
    return output
  }
  
  init() {
    var holeOffsets: [SIMD3<Float>] = []
    
    // Create the operand rods.
    var operandBoundsSet: [SIMD2<Float>] = []
    operandBoundsSet.append(SIMD2(2, 6))
    operandBoundsSet.append(3.25 + SIMD2(8, 12))
    
    let operandLattice = Self.createLattice(boundsSet: operandBoundsSet)
    var operandRod = Rod(lattice: operandLattice)
    operandRod.rigidBody.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    do {
      var center = operandRod.rigidBody.centerOfMass
      center = SIMD3(center.z, center.y, center.x)
      operandRod.rigidBody.centerOfMass = center
    }
    
    do {
      var offset = SIMD3<Float>(0.5, 0.5, 0)
      var source = operandRod
      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      operandA = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0.5 + 6, 0.5, 0)
      var source = operandRod
      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      operandB = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsets.append(offset)
    }
    
    // Create the sum rods.
    var sumBoundsSet: [SIMD2<Float>] = []
    sumBoundsSet.append(SIMD2(2, 6))
    sumBoundsSet.append(SIMD2(8, 12))
    
    let sumLattice = Self.createLattice(boundsSet: sumBoundsSet)
    var sumRod = Rod(lattice: sumLattice)
    sumRod.rigidBody.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    do {
      var center = sumRod.rigidBody.centerOfMass
      center = SIMD3(center.z, center.y, center.x)
      sumRod.rigidBody.centerOfMass = center
    }
    
    do {
      var offset = SIMD3<Float>(0.5 + 6 * 2, 0.5, 0)
      
      // Correct for the extra spacing at the barrier between drive walls.
      offset.x += 2
      var source = sumRod
      let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      sum = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
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
    var rampPatterns = HalfAdder.createBoundingPatterns()
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = -3.25 + 6 * Float(layerID)
        rampPatterns.append(
          Self.createRampPattern(offset: SIMD3(0, y, 0) + offset))
      }
    }
    
    // Create the operand drive wall.
    let operandPattern: RampPattern = { h, k, l in
      Origin { 14 * h }
      Plane { h }
      Replace { .empty }
    }
    operandDriveWall = Self.createDriveWall(
      patterns: rampPatterns + [operandPattern])
    
    // Create the sum drive wall.
    let sumPattern: RampPattern = { h, k, l in
      Origin { 15 * h }
      Plane { -h }
      Replace { .empty }
    }
    sumDriveWall = Self.createDriveWall(
      patterns: rampPatterns + [sumPattern])
  }
}

// MARK: - Rods

extension InputUnit {
  // Create a lattice for a logic rod.
  static func createLattice(boundsSet: [SIMD2<Float>]) -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 21 * h + 2 * h2k + 2 * l }
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
          Origin { 1.5 * h2k }
          Plane { h2k }
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

extension InputUnit {
  static func createHolePattern(offset: SIMD3<Float>) -> HolePattern {
    { h, k, l in
      Origin { offset[0] * h + offset[1] * k + offset[2] * l }
      
      Concave {
        Concave {
          Plane { h }
          Plane { k }
        }
        Concave {
          Origin { 4 * h + 4.25 * k }
          Plane { -h }
          Plane { -k }
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
          Plane { h }
          Plane { k }
        }
        Concave {
          Origin { 4 * h }
          Plane { -h }
        }
        Concave {
          Plane { -k + l }
          Origin { 2 * l }
          Plane { l }
        }
      }
      
      Replace { .empty }
    }
  }
  
  static func createDriveWall(patterns: [RampPattern]) -> DriveWall {
    var driveWallDesc = DriveWallDescriptor()
    driveWallDesc.dimensions = SIMD3(23, 18, 15)
    driveWallDesc.patterns = patterns
    driveWallDesc.patterns.append { h, k, l in
      Origin { 1 * l }
      Plane { -l }
      Replace { .empty }
    }
    driveWallDesc.patterns.append { h, k, l in
      Origin { 5.5 * l }
      Plane { l }
      Replace { .empty }
    }
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    var driveWall = DriveWall(descriptor: driveWallDesc)
    driveWall.rigidBody.centerOfMass.z -= (5.5 + 1) * latticeConstant
    return driveWall
  }
}
