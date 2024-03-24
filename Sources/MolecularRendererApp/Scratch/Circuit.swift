//
//  Circuit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Circuit {
  var input = InputUnit()
  var propagate = PropagateUnit()
  var generate = GenerateUnit()
  var output = OutputUnit()
  
  var rods: [Rod] {
    input.rods +
    propagate.rods +
    generate.rods +
    output.rods
  }
  
  init() {
    for layerID in 0..<5 {
      let y = 6 * Float(layerID)
      
      // The inputs to the circuit.
      if layerID > 0 {
        input.operandA.append(createRodZ(offset: SIMD3(0, y + 0, 0)))
        input.operandB.append(createRodZ(offset: SIMD3(5.5, y + 0, 0)))
      }
      
      // The propagate signals.
      if layerID > 0 {
        let offset = SIMD3(0, y + 2.5, 24 + 2.5)
        let rod = createRodX(offset: offset)
        propagate.signal.append(rod)
      }
      
      // The 'propagate' signals, broadcasted to every bit in the circuit.
      for positionX in 0..<layerID {
        let x = 5.5 * Float(positionX)
        let offset = SIMD3(x + 16.5, y + 0, 0)
        let rod = createRodZ(offset: offset)
        propagate.broadcast.append(rod)
      }
      
      // The signals that initiate carry chains.
      do {
        let z = 5.75 * Float(4 - layerID)
        let offset = SIMD3(0, y + 2.5, z + 0)
        let rod = createRodX(offset: offset)
        generate.signal.append(rod)
      }
      
      // The carry chains that propagate to the current bit.
      for positionZ in (4 - layerID)...4 {
        let z = 5.75 * Float(positionZ)
        let offset = SIMD3(0, y + 2.5, z + 0)
        let rod = createRodX(offset: offset)
        generate.broadcast.append(rod)
      }
      
      // The carry bits for the final computation.
      if layerID > 0 {
        let offset = SIMD3(41, y + 0, 0)
        let rod = createRodZ(offset: offset)
        output.carry.append(rod)
      }
    }
    
    // Query whether each generate signal is active.
    for positionZ in 0..<3 {
      // TODO: Flip the orientation toward the one with optimal packing.
      let z = 5.75 * Float(positionZ)
      let offset = SIMD3(11, 0, z + 2.5)
      let rod = createRodY(offset: offset)
      generate.query.append(rod)
    }
    
    // Query whether each propagate signal is active.
    for positionX in 0..<3 {
      let x = 5.5 * Float(positionX)
      let offset = SIMD3(x + 14, 0, 21.25 + 2.5)
      let rod = createRodY(offset: offset)
      propagate.query.append(rod)
    }
  }
}

extension Circuit {
  func createRodX(offset: SIMD3<Float>) -> Rod {
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
  
  func createRodY(offset: SIMD3<Float>) -> Rod {
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
  
  func createRodZ(offset: SIMD3<Float>) -> Rod {
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
