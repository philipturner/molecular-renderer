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
    
    // Create the lower rods.
    
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
    
    do {
      let offset = SIMD3<Float>(1, 1, 0)
      operandA = rodZ
      operandA.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      operandA.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(1.5, 1.5, 0) + offset))
    }
    
    do {
      let offset = SIMD3<Float>(1 + 5.75, 1, 0)
      operandB = rodZ
      operandB.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      operandB.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(1.5, 1.5, 0) + offset))
    }
    
    do {
      let offset = SIMD3<Float>(1 + 5.75 * 2, 1, 0)
      output = rodZ
      output.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      output.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      holePatterns.append(
        Self.createHolePatternZ(offset: SIMD3(1.5, 1.5, 0) + offset))
    }
    
    // Create the upper rods.
    
    let latticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    var rodX = Rod(lattice: latticeX)
    rodX.rigidBody.rotate(angle: -.pi, axis: [0, 1, 0])
    do {
      var center = rodX.rigidBody.centerOfMass
      center = SIMD3(-center.x, center.y, center.z)
      center.x += 20.5 * latticeConstant
      rodX.rigidBody.centerOfMass = center
    }
    
    do {
      let offset = SIMD3<Float>(0, 1 + 2.5, 1)
      propagate = rodX
      propagate.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      propagate.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      holePatterns.append(
        Self.createHolePatternX(offset: SIMD3(0, 1.5, 1.5) + offset))
    }
    
    do {
      let offset = SIMD3<Float>(0, 1 + 2.5, 1 + 5.75)
      generate = rodX
      generate.rigidBody.centerOfMass += SIMD3(offset) * latticeConstant
      generate.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
      holePatterns.append(
        Self.createHolePatternX(offset: SIMD3(0, 1.5, 1.5) + offset))
    }
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
}
