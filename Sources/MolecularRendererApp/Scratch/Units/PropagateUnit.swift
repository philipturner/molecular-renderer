//
//  PropagateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

// TODO: Store 'broadcast' uncompressed, but make the rods nullable.

struct PropagateUnit {
  // The propagate signal.
  //
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // The propagate signal, transmitted vertically.
  //
  // Ordered from bit 0 -> bit 3.
  var query: [Rod] = []
  
  // The propagate signal, broadcasted to every applicable carry chain.
  //
  // Stored in a compressed order.
  var broadcast: [Rod] = []
  
  var rods: [Rod] {
    signal +
    query +
    broadcast
  }
  
  init() {
    for layerID in 1...4 {
      let y = 6 * Float(layerID)
      
      // Create 'signal'.
      do {
        let offset = SIMD3(0, y + 2.5, 24 + 2.5)
        let rod = PropagateUnit.createRodX(offset: offset)
        signal.append(rod)
      }
      
      // Create 'broadcast'.
      for positionX in 0..<layerID {
        let x = 5.5 * Float(positionX)
        let offset = SIMD3(x + 16.5, y + 0, 0)
        let rod = PropagateUnit.createRodZ(offset: offset)
        broadcast.append(rod)
      }
    }
    
    // Create 'query'.
    for positionX in 0..<3 {
      let x = 5.5 * Float(positionX)
      let offset = SIMD3(x + 14, 0, 21.25 + 2.5)
      let rod = PropagateUnit.createRodY(offset: offset)
      query.append(rod)
    }
  }
}

extension PropagateUnit {
  private static func createRodX(offset: SIMD3<Float>) -> Rod {
    let rodLatticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 68 * h + 2 * h2k + 2 * l }
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
  
  private static func createRodY(offset: SIMD3<Float>) -> Rod {
    let rodLatticeY = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 45 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let atoms = rodLatticeY.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position = SIMD3(position.z, position.x, position.y)
      position += SIMD3(0.91, 0, 0.85)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
  
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
