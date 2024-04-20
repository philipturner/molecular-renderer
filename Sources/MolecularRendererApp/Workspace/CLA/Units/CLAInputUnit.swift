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
    let operandRodLattice = Rod.createLattice(
      length: (6 * 6) + 4)
    var operandRod = Rod(lattice: operandRodLattice)
    operandRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    
    // Create the A input.
    for layerID in 1...4 {
      var rod = operandRod
      rod.translate(y: Double(layerID) * 6)
      operandA.append(rod)
    }
    
    // Create the B input.
    for layerID in 1...4 {
      var rod = operandRod
      rod.translate(x: 6)
      rod.translate(y: Double(layerID) * 6)
      operandA.append(rod)
    }
  }
}
