//
//  Bootstrapping_Probe.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import HDL
import MolecularRenderer
import Numerics

// An AFM probe, where a sharp tooltip is built in 248 atom placements.

extension Bootstrapping {
  struct Probe {
    var atoms: [MRAtom]
    
    // Eventually, there will be a function to move the entire probe (as well
    // as a similar one to move the surface + tripods + build plate scene). For
    // now, hard-code a specific position into the initializer.
    init() {
      let lattice = Lattice<Cubic> { h, k, l in
        Bounds { 30 * (h + k + l) }
        Material { .elemental(.silicon) }
        
        Volume {
          var directions: [SIMD3<Float>] = []
          directions.append([1, 1, 0])
          directions.append([1, 0, 1])
          directions.append([0, 1, 1])
          directions.append([1, 0, 0])
          directions.append([0, 1, 0])
          directions.append([0, 0, 1])
          let direction111 = -SIMD3<Float>(1, 1, 1) / Float(3).squareRoot()
          let rotation = Quaternion<Float>(angle: .pi / 6, axis: direction111)
          
          for directionID in directions.indices {
            var adjusted = directions[directionID]
            var adjustedLength = (adjusted * adjusted).sum().squareRoot()
            adjusted /= adjustedLength
            
            let dotProduct = (adjusted * direction111).sum()
            adjusted -= direction111 * dotProduct
            adjustedLength = (adjusted * adjusted).sum().squareRoot()
            adjusted /= adjustedLength
            adjusted = rotation.act(on: adjusted)
            
            directions[directionID] = adjusted
          }
          
          var passes: [SIMD2<Float>] = []
          passes.append([2.50, 6.50])
          passes.append([4.50, 6.83])
          passes.append([5.50, 7.17])
          passes.append([6.00, 7.50])
          passes.append([6.50, 8.17])
          passes.append([7.00, 8.83])
          passes.append([7.50, 10.50])
          
          // TODO: Figure out how to remove the zones where bond topology
          // goes haywire. Either manually add planes, or create new bond
          // generation code. Investigate this later after Topology is finished
          // in the compiler.
          
          Concave {
            for pass in passes {
              let distanceWidth: Float = pass[0]
              let distanceHeight: Float = pass[1]
              
              Convex {
                Convex {
                  Origin { distanceHeight * (h + k + l) }
                  Plane { -(h + k + l) }
                }
                Convex {
                  Origin { 17 * (h + k + l) }
                  Plane { h + k + l }
                }
                for direction in directions {
                  Convex {
                    Origin { (distanceWidth + 0.01) * direction }
                    Plane { direction }
                  }
                }
              }
            }
          }
          
          Replace { .empty }
        }
      }
      print("silicon atoms:", lattice.entities.count)
      
      // Hydrogen-passivate using 'Diamondoid'. Then, use a deterministic rule
      // to fix up every pair of bad nearby hydrogens. Displace the silicons
      // that were reconstructed.
      let diamondoid = Diamondoid(atoms: lattice.entities.map(MRAtom.init))
      var siliconAtoms = diamondoid.atoms
      
      let axis1 = cross_platform_normalize([1, 0, -1])
      let axis3 = cross_platform_normalize([-1, -1, -1])
      let axis2 = cross_platform_cross(axis1, axis3)
      
      for i in siliconAtoms.indices {
        var position = siliconAtoms[i].origin
        let componentH = (position * SIMD3(axis1)).sum()
        let componentH2K = (position * SIMD3(axis2)).sum()
        let componentL = (position * SIMD3(axis3)).sum()
        position = SIMD3(componentH, -componentL, componentH2K)
        siliconAtoms[i].origin = position
      }
      
      // Shift the atoms, so that Y=0 coincides with the lowest atom.
      var minY: Float = .greatestFiniteMagnitude
      for atom in siliconAtoms {
        minY = min(minY, atom.origin.y)
      }
      for i in siliconAtoms.indices {
        siliconAtoms[i].origin.y -= minY
        
        // Shift the atoms by a hard-coded origin.
        siliconAtoms[i].origin += SIMD3(0, 1.5, 0)
      }
      self.atoms = siliconAtoms
    }
  }
}
