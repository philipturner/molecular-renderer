//
//  GenerateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct GenerateUnit {
  // The carry in.
  var carryIn: Rod
  
  // The generate signal.
  //
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // The generate signal, transmitted vertically.
  // - keys: The source layer (>= 0), or 'carryIn' (-1).
  // - values: The associated logic rods.
  var probe: [Int: Rod] = [:]
  
  // The carry chains that terminate at the current bit.
  // - keys: The source layer (lane 0) and the destination layer (lane 1).
  // - values: The associated logic rods.
  var broadcast: [SIMD2<Int>: Rod] = [:]
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    Array([carryIn]) +
    signal +
    Array(probe.values) +
    Array(broadcast.values)
  }
  
  init() {
    // Create 'carryIn'.
    do {
      let z = 5.75 * Float(4)
      let offset = SIMD3(0, 0, z + 0)
      let pattern: KnobPattern = { _, _, _ in }
      let rod = GenerateUnit
        .createRodX(offset: offset, pattern: pattern)
      carryIn = rod
    }
    
    for layerID in 1...4 {
      let y = 6 * Float(layerID)
      
      // Create 'generate'.
      do {
        let z = 5.75 * Float(4 - layerID)
        let offset = SIMD3(0, y, z + 0)
        let pattern: KnobPattern = { _, _, _ in }
        let rod = GenerateUnit
          .createRodX(offset: offset, pattern: pattern)
        signal.append(rod)
      }
      
      // Create 'broadcast'.
      for positionZ in (4 - layerID)...4 {
        let z = 5.75 * Float(positionZ)
        let offset = SIMD3(0, y, z + 0)
        let pattern: KnobPattern = { _, _, _ in }
        let rod = GenerateUnit
          .createRodX(offset: offset, pattern: pattern)
        
        let key = SIMD2(Int(positionZ), Int(layerID))
        broadcast[key] = rod
      }
    }
    
    // Create 'probe'.
    for positionZ in 0...3 {
      let z = 5.75 * Float(positionZ)
      let offset = SIMD3(10.75, 0, z + 3)
      let rod = GenerateUnit.createRodY(offset: offset)
      
      let key = 2 - positionZ
      probe[key] = rod
    }
  }
}

extension GenerateUnit {
  private static func createRodX(
    offset: SIMD3<Float>,
    pattern: KnobPattern
  ) -> Rod {
    let rodLatticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 77 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        pattern(h, h2k, l)
      }
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
      Bounds { 46 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let atoms = rodLatticeY.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position = SIMD3(position.y, position.x, position.z)
      position += SIMD3(0.85, 0, 0.91)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
}
