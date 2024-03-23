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
  }
}

struct Rods {
  var rods: [Rod] = []
  
  init() {
    let rodLatticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 68 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let rodLatticeY = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 40 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let rodLatticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 43 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    func createRodX(offset: SIMD3<Float>) -> Rod {
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
    
    for layerID in 0..<4 {
      let y = 6 * Float(layerID)
      
      for positionZ in 0..<5 {
        // Only send gather3 to bit 3.
        if positionZ == 0, layerID < 3 {
          continue
        }
        
        // Only send gather2 to bits 2 and 3.
        if positionZ == 1, layerID < 2 {
          continue
        }
        
        // Only send gather1 to bits 1, 2, and 3.
        if positionZ == 2, layerID < 1 {
          continue
        }
        
        let z = 5.75 * Float(positionZ)
        rods.append(createRodX(offset: SIMD3(0, y + 2.5, z + 0)))
      }
      for positionX in 0..<2 {
        let x = 5.5 * Float(positionX)
        rods.append(createRodZ(offset: SIMD3(x + 0, y + 0, 0)))
      }
      for positionX in 0..<5 {
        // Only create a rod at positionX=0 for the carry in.
        if positionX == 0, layerID > 0 {
          continue
        }
        
        // Only send propagate1 to bits 1, 2, and 3.
        if positionX == 2, layerID < 1 {
          continue
        }
        
        // Only send propagate2 to bits 2 and 3.
        if positionX == 3, layerID < 2 {
          continue
        }
        
        let x = 5.5 * Float(positionX)
        rods.append(createRodZ(offset: SIMD3(x + 13.5, y + 0, 0)))
      }
      rods.append(createRodZ(offset: SIMD3(41, y + 0, 0)))
    }
    
    for positionZ in 0..<4 {
      let z = 5.75 * Float(positionZ)
      rods.append(createRodY(offset: SIMD3(11, 0, z + 2.5)))
    }
    for positionX in 1..<5 {
      let x = 5.5 * Float(positionX)
      rods.append(createRodY(offset: SIMD3(x + 11, 0, 17.75 + 2.5)))
    }
  }
}
