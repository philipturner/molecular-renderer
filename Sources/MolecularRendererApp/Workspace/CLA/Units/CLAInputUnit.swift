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
    let operandRodLattice = Self.createLattice(
      length: 5 * 6 + 2)
    var operandRod = Rod(lattice: operandRodLattice)
    operandRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    
    // Create the A input.
    for layerID in 1...4 {
      var rod = operandRod
      rod.rigidBody.centerOfMass.y += Double(layerID) * 6 * 0.3567
      operandA.append(rod)
    }
    
    // Create the B input.
    for layerID in 1...4 {
      var rod = operandRod
      rod.rigidBody.centerOfMass.x += 6 * 0.3567
      rod.rigidBody.centerOfMass.y += Double(layerID) * 6 * 0.3567
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
