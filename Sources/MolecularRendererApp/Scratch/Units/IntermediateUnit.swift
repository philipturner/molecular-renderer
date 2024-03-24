//
//  IntermediateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct IntermediateUnit {
  // The carry bits for the final computation.
  //
  // Ordered from bit 0 -> bit 3.
  var carry: [Rod] = []
  
  // The carry out for the entire circuit.
  //
  // This is available 2 clock cycles before the sum, to minimize the critical
  // path in the circuit containing the adder.
  var carryOut: Rod
  
  // The value of A XOR B.
  var xor: [Rod] = []
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    carry +
    Array([carryOut]) +
    xor
  }
  
  init() {
    for layerID in 1...4 {
      let y = 6 * Float(layerID)
      
      // Create 'carry'.
      do {
        let offset = SIMD3(42, y - 3.25, 0)
        let rod = IntermediateUnit.createRodZ(offset: offset)
        carry.append(rod)
      }
      
      // Create 'xor'.
      do {
        let offset = SIMD3(47.5, y - 2.75, 0)
        let rod = IntermediateUnit.createRodZ(offset: offset)
        xor.append(rod)
      }
    }
    
    // Create 'carryOut'.
    do {
      let y = 6 * Float(5)
      let offset = SIMD3(42, y - 3.25, 0)
      let rod = IntermediateUnit.createRodZ(offset: offset)
      carryOut = rod
    }
  }
}

extension IntermediateUnit {
  private static func createRodZ(offset: SIMD3<Float>) -> Rod {
    let rodLatticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 54 * h + 2 * h2k + 2 * l }
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
