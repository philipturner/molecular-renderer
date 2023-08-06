//
//  VdwOscillator.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/6/23.
//

import Foundation
import MolecularRenderer
import simd

// Experiment with two oscillators side-by-side, the first non-superlubricating
// and the second superlubricating. At the time of creation, the MM4 simulator
// lacked a thermostat, so simulations couldn't last more than a few 100 ps.

struct VdwOscillator {
//  var provider: OpenMM_AtomProvider
  var provider: ArrayAtomProvider
  
  init() {
    // Generate a cube, then cleave it along directions I want.
    
    // We need a means to reconstruct (100) surfaces automatically.
    // - Detect cells with a nearby neighbor 90% omitted, except for its edge
    //   atoms, which are intact. That marks a (100) surface.
    // - Offset its atoms in a repeating pattern, which should align with nearby
    //   (100) surface tiles.
    // (110) surfaces don't need manual reconstruction.
    
    struct Cell {
      // Local coordinates within the cell, containing atoms that haven't been
      // removed yet. References to atoms may be duplicated across cells.
      var atoms: [SIMD3<Float>] = []
      
      var offset: SIMD3<Int>
      
      init() {
        self.offset = .zero
        
        for i in 0..<2 {
          for j in 0..<2 {
            for k in 0..<2 {
              if i ^ j ^ k == 0 {
                var position = SIMD3(Float(i), Float(j), Float(k))
                atoms.append(position)
                
                for axis in 0..<3 {
                  if position[axis] == 0 {
                    position[axis] = 0.25
                  } else {
                    position[axis] = 0.75
                  }
                }
                atoms.append(position)
              }
            }
          }
        }
        
        for axis in 0..<3 {
          var position = SIMD3<Float>(repeating: 0.5)
          position[axis] = 0
          atoms.append(position)
          
          position[axis] = 1
          atoms.append(position)
        }
      }
      
      // Atom-plane intersection function. Avoid planes that perfectly align
      // with the crystal lattice, as the results of intersection functions may
      // be unpredictable.
      mutating func cleave(origin: SIMD3<Float>, normal: SIMD3<Float>) {
        atoms = atoms.compactMap {
          let atomOrigin = $0 + SIMD3<Float>(self.offset)
          let delta = atomOrigin - origin
          let dotProduct = dot(delta, normal)
          if abs(dotProduct) < 1e-8 {
            fatalError("Cleaved along a perfect plane of atoms.")
          }
          if dotProduct > 0 {
            // Inside the bounding volume used to cleave atoms.
            return nil
          } else {
            // Outside the bounding volume.
            return $0
          }
        }
      }
      
      func cleaved(origin: SIMD3<Float>, normal: SIMD3<Float>) -> Cell {
        var copy = self
        copy.cleave(origin: origin, normal: normal)
        return copy
      }
      
      mutating func translate(offset: SIMD3<Int>) {
        self.offset &+= offset
      }
      
      func translated(offset: SIMD3<Int>) -> Cell {
        var copy = self
        copy.translate(offset: offset)
        return copy
      }
    }
    
    fatalError("Not implemented.")
  }
}
