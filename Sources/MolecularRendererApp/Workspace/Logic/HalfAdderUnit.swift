//
//  HalfAdder.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/11/24.
//

import Foundation
import HDL
import MM4
import Numerics

// The logic rods for a half adder.
struct HalfAdderUnit {
  var operandA: [Rod]
  var operandB: [Rod]
  var sum: [Rod]
  var propagate: [Rod]
  var generate: [Rod]
  
  var holePatterns: [HolePattern] = []
  var backRampPatterns: [RampPattern] = []
  var rightRampPatterns: [RampPattern] = []
  
  var rods: [Rod] {
    var output: [Rod] = []
    output.append(contentsOf: operandA)
    output.append(contentsOf: operandB)
    output.append(contentsOf: sum)
    output.append(contentsOf: propagate)
    output.append(contentsOf: generate)
    return output
  }
  
  init() {
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    
    let createDriveWallInterface: KnobPattern = { h, h2k, l in
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
    
    // MARK: - Lower Rods
    
    let latticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 21 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        createDriveWallInterface(h, h2k, l)
      }
    }
    
    var rodZ = Rod(lattice: latticeZ)
    rodZ.rigidBody.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    do {
      var center = rodZ.rigidBody.centerOfMass
      center = SIMD3(center.z, center.y, center.x)
      rodZ.rigidBody.centerOfMass = center
    }
    
    var holeOffsetsZ: [SIMD3<Float>] = []
    var backRampOffsets: [SIMD3<Float>] = []
    
    do {
      var offset = SIMD3<Float>(1, 1, 0)
      var source = rodZ
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      operandA = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsetsZ.append(offset)
      backRampOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(1 + 5.75, 1, 0)
      var source = rodZ
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      operandB = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsetsZ.append(offset)
      backRampOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(1 + 5.75 * 2, 1, 0)
      
      // Correct for the extra spacing at the barrier between drive walls.
      offset.x += 2.25
      var source = rodZ
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      sum = Self.createLayers(source: source)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsetsZ.append(offset)
      backRampOffsets.append(offset)
    }
    
    for offset in holeOffsetsZ {
      // Emulate the presence of other layers in the logic unit.
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(0, -6, 0) + offset))
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(0, 0, 0) + offset))
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(0, 6, 0) + offset))
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(0, 12, 0) + offset))
    }
    
    for var offset in backRampOffsets {
      offset.y -= 3.25
      
      // Emulate the presence of other layers in the logic unit.
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, -6, 0) + offset))
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, 0, 0) + offset))
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, 6, 0) + offset))
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, 12, 0) + offset))
    }
    
    // MARK: - Upper Rods
    
    let latticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 32 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        createDriveWallInterface(h, h2k, l)
      }
    }
    
    var rodX = Rod(lattice: latticeX)
    rodX.rigidBody.rotate(angle: -.pi, axis: [0, 1, 0])
    do {
      var center = rodX.rigidBody.centerOfMass
      center = SIMD3(-center.x, center.y, center.z)
      center.x += 22.75 * latticeConstant
      rodX.rigidBody.centerOfMass = center
    }
    
    var holeOffsetsX: [SIMD3<Float>] = []
    var rightRampOffsets: [SIMD3<Float>] = []
    
    do {
      var offset = SIMD3<Float>(0, 1 + 2.5, 1)
      var source = rodX
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      propagate = Self.createLayers(source: source)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsetsX.append(offset)
      rightRampOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0, 1 + 2.5, 1 + 5.75)
      var source = rodX
      source.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      source.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      generate = Self.createLayers(source: source)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsetsX.append(offset)
      rightRampOffsets.append(offset)
    }
    
    for offset in holeOffsetsX {
      // Emulate the presence of other layers in the logic unit.
      holePatterns.append(
        Self.createHolePatternX(offset: SIMD3(0, -6, 0) + offset))
      holePatterns.append(
        Self.createHolePatternX(offset: SIMD3(0, 0, 0) + offset))
      holePatterns.append(
        Self.createHolePatternX(offset: SIMD3(0, 6, 0) + offset))
      holePatterns.append(
        Self.createHolePatternX(offset: SIMD3(0, 12, 0) + offset))
    }
    
    for var offset in rightRampOffsets {
      offset.y -= 3.25
      
      // Emulate the presence of other layers in the logic unit.
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, -6, 0) + offset))
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, 0, 0) + offset))
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, 6, 0) + offset))
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, 12, 0) + offset))
    }
  }
}

extension HalfAdderUnit {
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
  
  static func createHolePatternX(offset: SIMD3<Float>) -> HolePattern {
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
  
  static func createRampPatternX(offset: SIMD3<Float>) -> RampPattern {
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
}
