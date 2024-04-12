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
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let latticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 21 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      // Drive wall interface.
      Volume {
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
    
    var rodZ = Rod(lattice: latticeZ)
    rodZ.rigidBody.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    do {
      var center = rodZ.rigidBody.centerOfMass
      center = SIMD3(center.z, center.y, center.x)
      rodZ.rigidBody.centerOfMass = center
    }
    
    var holeOffsets: [SIMD3<Float>] = []
    
    do {
      var offset = SIMD3<Float>(0.75, 0.75, 0)
      var source = rodZ
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      operandA = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0.75 + 6.25, 0.75, 0)
      var source = rodZ
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      operandB = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0.75 + 6.25 * 2, 0.75, 0)
      
      // Correct for the extra spacing at the barrier between drive walls.
      offset.x += 1.75
      var source = rodZ
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      sum = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsets.append(offset)
    }
    
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = 6.25 * Float(layerID)
        holePatterns.append(
          Self.createHolePatternZ(offset: SIMD3(0, y, 0) + offset))
      }
    }
    
    var rampPatterns = HalfAdder.createBoundingPatterns()
    for offset in holeOffsets {
      // Emulate the presence of other layers in the logic unit.
      for layerID in -1...2 {
        let y = -3.25 + 6.25 * Float(layerID)
        rampPatterns.append(
          Self.createRampPatternZ(offset: SIMD3(0, y, 0) + offset))
      }
    }
    
    let operandPattern: RampPattern = { h, k, l in
      Origin { 14 * h }
      Plane { h }
      Replace { .empty }
    }
    operandDriveWall = Self.createDriveWall(
      patterns: rampPatterns + [operandPattern])
    
    let sumPattern: RampPattern = { h, k, l in
      Origin { 15 * h }
      Plane { -h }
      Replace { .empty }
    }
    sumDriveWall = Self.createDriveWall(
      patterns: rampPatterns + [sumPattern])
  }
}

extension InputUnit {
  // Spawns the logic rods for all Y layers, from a single source rod.
  static func createLayers(source: Rod) -> [Rod] {
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let spacing = 6.25 * latticeConstant
    
    var output: [Rod] = []
    for layerID in 0..<2 {
      var rod = source
      rod.rigidBody.centerOfMass.y += spacing * Double(layerID)
      output.append(rod)
    }
    return output
  }
  
  static func createHolePatternZ(offset: SIMD3<Float>) -> HolePattern {
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
  
  static func createRampPatternZ(offset: SIMD3<Float>) -> RampPattern {
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
}

extension InputUnit {
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
