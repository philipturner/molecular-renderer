//
//  Bootstrapping_Surface.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import HDL
import MolecularRenderer
import Numerics

// The surface needs to be improved, so that it's more realistic.
//
// 0) Wait to change this until the code for controlling the AFM is sorted out.
//    Having less surface area (and therefore higher tip conc.) is a
//    conservative estimate of device performance. Not adding the ledges will
//    make the code much simpler when first implementing it.
// 1) Make the gold surface maximally thin so you can fit more surface area
//    with the same rendering cost.
// 2) Achieve this by emulating a few randomly spaced ledges (within a certain
//    margin of safety from the central build plate). This makes it a bit
//    harder to plan trajectories and better represents real-world conditions.
//
// Finish the rest of this scene another time; each component of the project
// can be worked on in bits.

extension Bootstrapping {
  struct Surface {
    var atoms: [MRAtom]
    
    init() {
      // Create a hexagon of gold. Make it truly gigantic.
      let scaleFactor: Float = 4
      let lattice = Lattice<Cubic> { h, k, l in
        Bounds { scaleFactor * 40 * (h + k + l) }
        Material { .elemental(.gold) }
        
        Volume {
          Convex {
            Origin { scaleFactor * 20 * (h + k + l) }
            
            for direction in [h + k + l, -h - k - l] {
              Convex {
                Origin { 0.5 * direction }
                Plane { direction }
              }
            }
            
            // Change the chiseling on the 3 (110) sides.
            for direction in [h + k, h + l, k + l] {
              Convex {
                Origin { scaleFactor * 10 * direction }
                Plane { direction }
              }
            }
          }
          
          // Change the chiseling on the 3 (100) sides.
          for direction in [h - k - l, k - h - l, l - h - k] {
            Convex {
              Origin { scaleFactor * 6.75 * direction }
              Plane { direction }
            }
          }
          
          Replace { .empty }
        }
      }
      
      // 50,000 gold atoms
      var goldAtoms = lattice.entities
      print("gold atoms:", goldAtoms.count)
      
      // Center the surface at the world origin.
      func center() {
        var centerOfMass: SIMD3<Double> = .zero
        for entity in goldAtoms {
          centerOfMass += SIMD3(entity.position)
        }
        centerOfMass /= Double(goldAtoms.count)
        for i in goldAtoms.indices {
          goldAtoms[i].position -= SIMD3(centerOfMass)
        }
      }
      center()
      
      // Rotate the hexagon so its normal points toward +Y.
      let axis1 = cross_platform_normalize([1, 0, -1])
      let axis3 = cross_platform_normalize([1, 1, 1])
      let axis2 = cross_platform_cross(axis1, axis3)
      
      for i in goldAtoms.indices {
        var position = goldAtoms[i].position
        let componentH = (position * SIMD3(axis1)).sum()
        let componentH2K = (position * SIMD3(axis2)).sum()
        let componentL = (position * SIMD3(axis3)).sum()
        position = SIMD3(componentH, componentL, componentH2K)
        goldAtoms[i].position = position
      }
      
      // Center it again.
      center()
      
      // Shift the atoms, so that Y=0 coincides with the highest atom.
      var maxY: Float = -.greatestFiniteMagnitude
      for atom in goldAtoms {
        maxY = max(maxY, atom.position.y)
      }
      print(maxY)
      for i in goldAtoms.indices {
        goldAtoms[i].position.y -= maxY
      }
      
      self.atoms = goldAtoms.map(MRAtom.init)
    }
  }
}
