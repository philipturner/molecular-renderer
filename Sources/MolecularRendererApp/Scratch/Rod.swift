//
//  Rod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/23/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Rod {
  var topology = Topology()
  
  init(atoms: [Entity]) {
    topology.insert(atoms: atoms)
    passivate()
  }
  
  // Adds hydrogens and reorders the atoms for efficient simulation.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}

struct Rods {
  // Ordered from bit 0 -> bit 3.
  var inputA: [Rod] = []
  
  // Ordered from bit 0 -> bit 3.
  var inputB: [Rod] = []
  
  // Ordered from bit 0 -> bit 3.
  var carry: [Rod] = []
  
  // Ordered from bit 0 -> bit 3.
  var generate: [Rod] = []
  
  // Ordered from bit 0 -> bit 3.
  var propagateSource: [Rod] = []
  
  // Stored in a compressed order.
  // [p0, p1, p2, p3] -> [0, 1, 2, 3]
  //     [p1, p2, p3] ->    [4, 5, 6]
  //         [p2, p3] ->       [7, 8]
  //             [p3] ->          [9]
  var propagateBroadcast: [Rod] = []
  
  // Stored in a compressed order.
  var sequence: [Rod] = []
  
  // Not sorted in an identifiable order.
  var unlabeled: [Rod] = []
  
  var allRods: [Rod] {
    inputA +
    inputB +
    carry +
    generate +
    propagateSource +
    propagateBroadcast +
    sequence +
    unlabeled
  }
  
  init() {
    for layerID in 0..<5 {
      let y = 6 * Float(layerID)
      
      // The inputs to the circuit.
      if layerID > 0 {
        inputA.append(createRodZ(offset: SIMD3(0, y + 0, 0)))
        inputB.append(createRodZ(offset: SIMD3(5.5, y + 0, 0)))
      }
      
      // Right-pointing rods that each represent a possible carry sequence.
      for positionZ in 0..<5 {
        // Only send generate3 to bit 3.
        if positionZ == 0, layerID < 4 {
          continue
        }
        
        // Only send generate2 to bits 2 and 3.
        if positionZ == 1, layerID < 3 {
          continue
        }
        
        // Only send generate1 to bits 1, 2, and 3.
        if positionZ == 2, layerID < 2 {
          continue
        }
        
        // Only send generate0 to bits 0, 1, 2, and 3.
        if positionZ == 3, layerID < 1 {
          continue
        }
        
        let z = 5.75 * Float(positionZ)
        if positionZ + layerID == 4 {
          generate.append(createRodX(offset: SIMD3(0, y + 2.5, z + 0)))
        } else {
          sequence.append(createRodX(offset: SIMD3(0, y + 2.5, z + 0)))
        }
      }
      
      // The original propagate signals.
      if layerID > 0 {
        propagateSource.append(createRodX(offset: SIMD3(0, y + 2.5, 24 + 2.5)))
      }
      
      // The 'propagate' signals, broadcasted to every bit in the circuit.
      for positionX in 0..<4 {
        // Only send to yourself and later layers.
        guard layerID > positionX else {
          continue
        }
        
        let x = 5.5 * Float(positionX)
        propagateBroadcast.append(
          createRodZ(offset: SIMD3(x + 16.5, y + 0, 0)))
      }
      
      // The carry input to the full adder.
      if layerID > 0 {
        carry.append(createRodZ(offset: SIMD3(41, y + 0, 0)))
      }
    }
    
    // TODO: Fix the logic, because the carry in can't be clocked in the
    // current position. Try placing the carry-in on the left/right side,
    // instead of the front side.
    //
    // Or, simplify everything. The carry in is a vertical rod.
    
    // Some rods for sending signals between lanes.
    for positionZ in 0..<3 {
      let z = 5.75 * Float(positionZ)
      unlabeled.append(createRodY(offset: SIMD3(11, 0, z + 2.5)))
    }
    for positionX in 0..<3 {
      let x = 5.5 * Float(positionX)
      unlabeled.append(createRodY(offset: SIMD3(x + 14, 0, 21.25 + 2.5)))
    }
  }
}

extension Rods {
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
      Bounds { 40 * h + 2 * h2k + 2 * l }
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
