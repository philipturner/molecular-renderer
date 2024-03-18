//
//  System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/18/24.
//

import Foundation
import HDL
import MM4

// An HDL description of the knobs for each rod.
struct Pattern {
  var rodA: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
  var rodB: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
  var rodC: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
}
//
// Example of a pattern:
#if false
func examplePattern() {
  pattern.rodA = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Origin { 2 * h2k }
      Concave {
        Origin { 1.5 * h }
        Plane { h + k }
        
        Origin { -0.5 * h2k }
        Plane { h2k }
        
        Origin { 5.5 * h }
        Plane { k }
      }
      Replace { .empty }
    }
  }
  pattern.rodB = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Origin { 2 * h2k }
      Concave {
        Origin { 1.5 * h }
        Plane { h + k }
        
        Origin { -0.5 * h2k }
        Plane { h2k }
        
        Origin { 5.5 * h }
        Plane { k }
      }
      Replace { .empty }
    }
  }
  pattern.rodC = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        Origin { 1.5 * h }
        Plane { -k }
        
        Origin { 0.5 * h2k }
        Plane { -h2k }
        
        Origin { 5.5 * h }
        Plane { -h - k }
      }
      Concave {
        Origin { 10.5 * h }
        Plane { -k }
        
        Origin { 0.5 * h2k }
        Plane { -h2k }
        
        Origin { 5.0 * h }
        Plane { -h - k }
      }
      Replace { .empty }
    }
  }
}
#endif

struct System {
  var housing: Housing
  var rodA: Rod
  var rodB: Rod
  var rodC: Rod
  
  init(pattern: Pattern) {
    housing = Housing()
    
    var rodDescriptor = RodDescriptor()
    rodDescriptor.length = 10
    rodDescriptor.pattern = pattern.rodA
    rodA = Rod(descriptor: rodDescriptor)
    
    // Align the rod with the housing.
    for atomID in rodA.topology.atoms.indices {
      var atom = rodA.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      position += SIMD3(0.9, 0.85, 0)
      atom.position = position
      rodA.topology.atoms[atomID] = atom
    }
    
    rodDescriptor.length = 10
    rodDescriptor.pattern = pattern.rodB
    rodB = Rod(descriptor: rodDescriptor)
    
    // Align the rod with the housing.
    for atomID in rodB.topology.atoms.indices {
      var atom = rodB.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      position += SIMD3(0.9 + 6 * 0.357, 0.85, 0)
      atom.position = position
      rodB.topology.atoms[atomID] = atom
    }
    
    rodDescriptor.length = 20
    rodDescriptor.pattern = pattern.rodC
    rodC = Rod(descriptor: rodDescriptor)
    
    // Align the rod with the housing.
    for atomID in rodC.topology.atoms.indices {
      var atom = rodC.topology.atoms[atomID]
      var position = atom.position
      position += SIMD3(0, 1.83, 0.9)
      atom.position = position
      rodC.topology.atoms[atomID] = atom
    }
  }
  
  mutating func passivate() {
    housing.passivate()
    rodA.passivate()
    rodB.passivate()
    rodC.passivate()
  }
}
