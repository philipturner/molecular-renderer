import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Compile an axle, and a sheet of diamond that will curl around it.
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 20 * h + 20 * k + 2 * l }
    Material { .elemental(.carbon) }
    
    // Trim away two opposing corners of the square.
    Volume {
      Convex {
        Origin { 5 * k }
        Plane { -h + k }
      }
      Convex {
        Origin { 5 * h }
        Plane { h - k }
      }
      Replace { .empty }
    }
    
    // Shorten the remaining points.
    // TODO: Do this after checking the radius of curvature.
    
    // Replace the back side with sulfur.
    Volume {
      Origin { 0.25 * l }
      Plane { -l }
      Replace { .atom(.sulfur) }
    }
    
    // Replace the front side with a series of grooves.
    Volume {
      for diagonalID in -5...5 {
        Concave {
          Origin { Float(diagonalID) * (h - k) }
          Origin { 2 * l }
          
          Convex {
            Origin { -0.25 * l }
            Plane { l }
          }
          Convex {
            Origin { -0.25 * (h - k) }
            Plane { h - k }
          }
          Convex {
            Origin { -0.25 * (-h + k) }
            Plane { -h + k }
          }
        }
      }
      
      Replace { .empty }
    }
  }
  
  // Reconstruct the surface.
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .elemental(.carbon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  var topology = reconstruction.topology
  
  // Fetch the neighbors map.
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  let atomsToBondsMap = topology.map(.atoms, to: .bonds)
  
  // Remove the incorrect bonds and passivators.
  var removedAtoms: [UInt32] = []
  var removedBonds: [UInt32] = []
  for i in topology.atoms.indices {
    let atom = topology.atoms[i]
    guard atom.atomicNumber == 16 else {
      continue
    }
    
    let atomsMap = atomsToAtomsMap[i]
    let bondsMap = atomsToBondsMap[i]
    for internalBondID in atomsMap.indices {
      let j = atomsMap[internalBondID]
      let otherAtom = topology.atoms[Int(j)]
      let bondID = bondsMap[internalBondID]
      let bond = topology.bonds[Int(bondID)]
      
      
    }
  }
  
  return topology.atoms
}
