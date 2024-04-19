//
//  CLAInputUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAInputUnit {
  // The A input to the circuit.
  //
  // Ordered from bit 0 -> bit 3.
  var operandA: [Rod] = []
  
  // The B input to the circuit.
  //
  // Ordered from bit 0 -> bit 3.
  var operandB: [Rod] = []
  
  var rods: [Rod] {
    operandA + operandB
  }
  
  init() {
    let baseRodLattice = Self.createLattice(length: 6 * 5)
    var baseRod = Rod(lattice: baseRodLattice)
    baseRod.rigidBody.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    baseRod.rigidBody.centerOfMass = SIMD3(
      baseRod.rigidBody.centerOfMass.z,
      baseRod.rigidBody.centerOfMass.y,
      baseRod.rigidBody.centerOfMass.x)
    
    // Create the A input.
    for layerID in 0..<4 {
      var rod = baseRod
      rod.rigidBody.centerOfMass += SIMD3(0.5, 0.5, 0) * 0.3567
      rod.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      rod.rigidBody.centerOfMass.y += Double(layerID) * (6 * 0.3567)
      operandA.append(rod)
    }
    
    // Create the B input.
    for layerID in 0..<4 {
      var rod = baseRod
      rod.rigidBody.centerOfMass += SIMD3(6.5, 0.5, 0) * 0.3567
      rod.rigidBody.centerOfMass += SIMD3(0.91, 0.85, 0)
      rod.rigidBody.centerOfMass.y += Double(layerID) * (6 * 0.3567)
      operandA.append(rod)
    }
  }
  
  static func createLattice(length: Int) -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      
      var dimensionH = Float(length)
      dimensionH *= Constant(.square) { .elemental(.carbon) }
      dimensionH /= Constant(.hexagon) { .elemental(.carbon) }
      dimensionH.round(.up)
      Bounds { dimensionH * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
  }
}
