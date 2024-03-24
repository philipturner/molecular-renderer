//
//  InputUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct InputUnit {
  // The A input to the circuit.
  //
  // Ordered from bit 0 -> bit 3.
  var operandA: [Rod] = []
  
  // The B input to the circuit.
  //
  // Ordered from bit 0 -> bit 3.
  var operandB: [Rod] = []
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    operandA +
    operandB
  }
  
  init() {
    for layerID in 1...4 {
      let y = 6.25 * Float(layerID)
      
      // Create 'operandA'.
      do {
        let offset = SIMD3(0, y + 0, 0)
        let rod = InputUnit.createRodZ(offset: offset)
        operandA.append(rod)
      }
      
      // Create 'operandB'.
      do {
        let offset = SIMD3(5.5, y + 0, 0)
        let rod = InputUnit.createRodZ(offset: offset)
        operandB.append(rod)
      }
    }
  }
}

extension InputUnit {
  private static func createRodZ(offset: SIMD3<Float>) -> Rod {
    let rodLatticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 50 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let atoms = rodLatticeZ.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position = SIMD3(position.z, position.y, position.x)
      position += SIMD3(0.91, 0.85, 0)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
}
