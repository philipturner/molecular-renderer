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
  var operandA: Rod
  var operandB: Rod
  var output: Rod
  var propagate: Rod
  var generate: Rod
  
  var holePatterns: [HolePattern] = []
  var backRampPatterns: [RampPattern] = []
  var rightRampPatterns: [RampPattern] = []
  
  var rods: [Rod] {
    return [
      operandA,
      operandB,
      output,
      propagate,
      generate,
    ]
  }
  
  init() {
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    
    // MARK: - Lower Rods
    
    let latticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 21 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
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
      operandA = rodZ
      operandA.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      operandA.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsetsZ.append(offset)
      backRampOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(1 + 5.75, 1, 0)
      operandB = rodZ
      operandB.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      operandB.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      
      offset += SIMD3(1.5, 1.5, 0)
      holeOffsetsZ.append(offset)
      backRampOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(1 + 5.75 * 2, 1, 0)
      
      // Correct for the extra spacing at the barrier between drive walls.
      offset.x += 2.25
      output = rodZ
      output.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      output.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      
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
    }
    
    for offset in backRampOffsets {
      // Emulate the presence of other layers in the logic unit.
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, -6, 0) + offset))
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, 0, 0) + offset))
      backRampPatterns.append(
        Self.createRampPatternZ(offset: SIMD3(0, 6, 0) + offset))
    }
    
    // MARK: - Upper Rods
    
    let latticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 32 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
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
      propagate = rodX
      propagate.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      propagate.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      
      offset += SIMD3(0, 1.5, 1.5)
      holeOffsetsX.append(offset)
      rightRampOffsets.append(offset)
    }
    
    do {
      var offset = SIMD3<Float>(0, 1 + 2.5, 1 + 5.75)
      generate = rodX
      generate.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      generate.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      
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
    }
    
    for offset in rightRampOffsets {
      // Emulate the presence of other layers in the logic unit.
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, -6, 0) + offset))
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, 0, 0) + offset))
      rightRampPatterns.append(
        Self.createRampPatternX(offset: SIMD3(22.75, 6, 0) + offset))
    }
  }
}

extension HalfAdderUnit {
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
          Origin { 1 * k + 1 * l }
          Plane { l }
          Plane { -k + l }
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
          Origin { 1 * -h + 1 * k }
          Plane { -h }
          Plane { -h - k }
        }
      }
      
      Replace { .empty }
    }
  }
}
