import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Compile an axle, and a sheet of diamond that will curl around it.
  let lattice = SheetPart.createLattice()
  let topology = SheetPart.createTopology(lattice: lattice)
  return topology.atoms
}

struct SheetPart: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    
    let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    minimize(bulkAtomIDs: bulkAtomIDs)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
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
      
      // Replace the front side with sulfur.
      Volume {
        Origin { 2 * l }
        Origin { -0.25 * l }
        Plane { l }
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
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
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
      for j in atomsMap {
        let otherAtom = topology.atoms[Int(j)]
        if otherAtom.atomicNumber == 1 {
          removedAtoms.append(j)
        }
      }
      
      let bondsMap = atomsToBondsMap[i]
      for bondID in bondsMap {
        let bond = topology.bonds[Int(bondID)]
        
        var j: UInt32
        if bond[0] == i {
          j = bond[1]
        } else if bond[1] == i {
          j = bond[0]
        } else {
          fatalError("This should never happen.")
        }
        
        let otherAtom = topology.atoms[Int(j)]
        if otherAtom.atomicNumber == 16 {
          removedBonds.append(bondID)
        }
      }
    }
    topology.remove(bonds: removedBonds)
    topology.remove(atoms: removedAtoms)
    
    let atomsToAtomsMap2 = topology.map(.atoms, to: .atoms)
    
    for i in topology.atoms.indices {
      var atom = topology.atoms[i]
      let neighbors = atomsToAtomsMap2[i]
      
      switch atom.atomicNumber {
      case 1:
        if neighbors.count < 1 {
          atom.atomicNumber = 9
        }
      case 6:
        if neighbors.count < 4 {
          atom.atomicNumber = 14
        }
      case 16:
        if neighbors.count < 2 {
          atom.atomicNumber = 8
        }
      default:
        fatalError()
      }
      
      topology.atoms[i] = atom
    }
    
    return topology
  }
}
