//
//  OutputUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct OutputUnit {
  // The NOR intermediate of the half adder.
  //
  // Ordered from bit 0 -> bit 3.
  var nor: [Rod] = []
  
  // The AND intermediate of the half adder.
  //
  // Ordered from bit 0 -> bit 3.
  var and: [Rod] = []
  
  // The sum output of the half adder.
  var sum: [Rod] = []
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    nor +
    and +
    sum
  }
  
  init() {
    for layerID in 1...4 {
      let y = 6 * Float(layerID)
      
      // Create 'nor'.
      do {
        let offset = SIMD3(42, y, -13)
        let rod = OutputUnit.createRodX(offset: offset)
        nor.append(rod)
      }
      
      // Create 'and'.
      do {
        let offset = SIMD3(42, y, -18.5)
        let rod = OutputUnit.createRodX(offset: offset)
        and.append(rod)
      }
      
      // Create 'sum'.
      do {
        let offset = SIMD3(53, y - 2.75, -18.5)
        let rod = OutputUnit.createRodZ(offset: offset)
        sum.append(rod)
      }
    }
  }
}

extension OutputUnit {
  private static func createRodX(offset: SIMD3<Float>) -> Rod {
    let rodLatticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 26 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let atoms = rodLatticeX.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position += SIMD3(0, 0.85, 0.91)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
  
  private static func createRodZ(offset: SIMD3<Float>) -> Rod {
    let rodLatticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 18 * h + 2 * h2k + 2 * l }
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
