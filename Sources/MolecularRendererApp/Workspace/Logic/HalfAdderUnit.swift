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
      Bounds { 20 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    var rodZ = Rod(lattice: latticeZ)
    rodZ.rigidBody.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    do {
      var center = rodZ.rigidBody.centerOfMass
      center = SIMD3(center.z, center.y, center.x)
      rodZ.rigidBody.centerOfMass = center
    }
    
    operandA = rodZ
    operandA.rigidBody.centerOfMass += SIMD3(0, 0, 0) * latticeConstant
    operandA.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
    
    operandB = rodZ
    operandB.rigidBody.centerOfMass += SIMD3(5.75, 0, 0) * latticeConstant
    operandB.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
    
    output = rodZ
    output.rigidBody.centerOfMass += SIMD3(5.75 * 2, 0, 0) * latticeConstant
    output.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
    
    // Create the upper rods.
    
    let latticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    var rodX = Rod(lattice: latticeX)
    rodX.rigidBody.rotate(angle: -.pi, axis: [0, 1, 0])
    
    propagate = rodX
    propagate.rigidBody.centerOfMass += SIMD3(0, 2.5, 0) * latticeConstant
    propagate.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
    
    generate = rodX
    generate.rigidBody.centerOfMass += SIMD3(0, 2.5, 5.75) * latticeConstant
    generate.rigidBody.centerOfMass += SIMD3(0, 0.85, 0.91)
  }
}
