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
        Bounds { 80 * (h + k + l) }
        Material { .elemental(.silicon) }
        let topCutoff: Float = 67
        
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
          
          var passes: [SIMD4<Float>] = []
          passes.append([2.50, 6.50, 1.0, 0.5])
          passes.append([4.50, 6.83, 1.0, 0.5])
          passes.append([5.50, 7.17, 1.0, 0.5])
          passes.append([6.00, 7.50, 1.0, 0.5])
          passes.append([6.50, 8.17, 1.0, 0.5])
          passes.append([7.00, 8.83, 1.0, 0.5])
          passes.append([7.50, 9.50, 1.0, 0.5])
          passes.append([8.00, 10.83, 1.0, 0.5])
          
          passes.append([8.25, 12.83, 1.0, 0.5])
          passes.append([8.50, 14.83, 1.0, 0.5])
          passes.append([9.00, 17.17, 1.0, 0.5])
          passes.append([9.50, 20.17, 1.0, 0.5])
          passes.append([9.75, 23.17, 1.0, 0.5])
          passes.append([10.00, 27.17, 0.5, 0.25])
          passes.append([10.25, 31.17, 0.5, 0.25])
          passes.append([10.75, 36.17, 0.75, 0.5])
          passes.append([11.00, 41.17, 0.5, 0.25])
          passes.append([11.50, 47.17, 0.75, 0.5])
          passes.append([11.75, 53.17, 0.5, 0.25])
          
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
                  Origin { topCutoff * (h + k + l) }
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
          
          Convex {
            for pass in passes {
              let distanceWidth: Float = pass[0]
              let distanceHeight: Float = pass[1]
              let wallThickness: Float = pass[2]
              
              Concave {
                Convex {
                  Origin { (distanceHeight + wallThickness) * (h + k + l) }
                  Plane { (h + k + l) }
                }
                Convex {
                  Origin { 12 * (h + k + l) }
                  Plane { h + k + l }
                }
                Convex {
                  Origin { (topCutoff - 1) * (h + k + l) }
                  Plane { -(h + k + l) }
                }
                for direction in directions {
                  Convex {
                    Origin {
                      (distanceWidth + 0.01 - wallThickness) * direction
                    }
                    Plane { -direction }
                  }
                }
              }
            }
          }
          
          Replace { .empty }
          
          Convex {
            for pass in passes {
              let distanceWidth: Float = pass[0]
              let distanceHeight: Float = pass[1]
              let wallThickness: Float = pass[2]
              let carbonDelta: Float = pass[3]
              
              Concave {
                Convex {
                  Origin { (distanceHeight + wallThickness - carbonDelta) * (h + k + l) }
                  Plane { (h + k + l) }
                }
                Convex {
                  Origin { (12 - carbonDelta) * (h + k + l) }
                  Plane { h + k + l }
                }
                Convex {
                  Origin { (topCutoff - carbonDelta) * (h + k + l) }
                  Plane { -(h + k + l) }
                }
                for direction in directions {
                  Convex {
                    Origin {
                      (distanceWidth + 0.00 - wallThickness + carbonDelta) * direction
                    }
                    Plane { -direction }
                  }
                }
              }
            }
          }
          
          Replace { .atom(.carbon) }
        }
      }
      print("silicon atoms:", lattice.atoms.count)
      
      // Hydrogen-passivate using 'Diamondoid'. Don't worry about fixing the
      // instances of colliding hydrogens; invest time in other, more important
      // areas. There's a lot of other details to perfect.
      
      // Take note of all the atoms that were marked as carbons.
      var latticeAtoms = lattice.atoms.map(MRAtom.init)
      var latticeCarbons: [SIMD3<Float>: Bool] = [:]
      for i in latticeAtoms.indices {
        if latticeAtoms[i].element == 6 {
          latticeCarbons[latticeAtoms[i].origin] = true
          latticeAtoms[i].element = 14
        }
      }
      
      var diamondoid = Diamondoid(atoms: latticeAtoms)
      diamondoid.removeLooseCarbons(iterations: 0)
      
      // Remove hydrogens pointing inward.
      var atomsToRemove: [Int: Bool] = [:]
      for var bond in diamondoid.bonds {
        var atom1 = diamondoid.atoms[Int(bond[0])]
        var atom2 = diamondoid.atoms[Int(bond[1])]
        if atom1.element == 1 {
          swap(&atom1, &atom2)
          bond = SIMD2(bond[1], bond[0])
        }
        guard atom2.element == 1 else {
          continue
        }
        guard atom1.element == 14 else {
          fatalError("This should never happen.")
        }
        
        if latticeCarbons[atom1.origin] != nil {
          atomsToRemove[Int(bond[1])] = true
        }
      }
      
      var siliconAtoms = diamondoid.atoms.indices.compactMap { i -> MRAtom? in
        let atom = diamondoid.atoms[i]
        if atomsToRemove[i] != nil {
          return nil
        } else {
          return atom
        }
      }
      
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
