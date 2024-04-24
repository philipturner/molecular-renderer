import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // MARK: - Create Lattice
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 1 * h + 20 * k + 20 * l }
    Material { .elemental(.carbon) }
    
    // Remove some material, creating a cuboid at 45 degrees from the current
    // orientation.
    Volume {
      Convex {
        Origin { 15 * k }
        Plane { k - l }
        Plane { -k - l }
      }
      Convex {
        Origin { 5 * k }
        Origin { 15 * l }
        Plane { -k + l }
        Plane { k + l }
      }
      Replace { .empty }
    }
    
    // Remove an atomic layer, providing room for hydrogens.
//    Volume {
//      Concave {
//        Concave {
//          Origin { 0.25 * h }
//          Plane { -h }
//        }
//        Convex {
//          Convex {
//            Origin { 1.00 * (l - k) }
//            Plane { l - k }
//          }
//          Convex {
//            Origin { 1.00 * (k - l) }
//            Plane { k - l }
//          }
//        }
//      }
//      Replace { .empty }
//    }
    
    // Add sulfurs.
    Volume {
      Origin { 0.25 * h }
      Plane { -h }
      Replace { .atom(.sulfur) }
    }
  }
  
//  return lattice.atoms
  
  // MARK: - Reconstruct Surface
  
  var reconstruction = SurfaceReconstruction()
  reconstruction.material = .elemental(.carbon)
  reconstruction.topology.insert(atoms: lattice.atoms)
  reconstruction.compile()
  
  // MARK: - Remove Hydrogens from Sulfurs
  
  var topology = reconstruction.topology
  var atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  let atomsToBondsMap = topology.map(.atoms, to: .bonds)
  
  var removedAtoms: [UInt32] = []
  var removedBonds: [UInt32] = []
  for i in topology.atoms.indices {
    let atom = topology.atoms[i]
    if atom.atomicNumber == 1 {
      for j in atomsToAtomsMap[i] {
        let other = topology.atoms[Int(j)]
        if other.atomicNumber == 16 {
          removedAtoms.append(UInt32(i))
        }
      }
    } else if atom.atomicNumber == 16 {
      for bondID in atomsToBondsMap[i] {
        let bond = topology.bonds[Int(bondID)]
        var otherID: UInt32
        if bond[0] == i {
          otherID = bond[1]
        } else if bond[1] == i {
          otherID = bond[0]
        } else {
          fatalError("Unexpected bond.")
        }
        
        let other = topology.atoms[Int(otherID)]
        if other.atomicNumber == 16 {
          removedBonds.append(UInt32(bondID))
        }
      }
    }
  }
  topology.remove(bonds: removedBonds)
  topology.remove(atoms: removedAtoms)
  
  atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  
  for i in topology.atoms.indices {
    let atom = topology.atoms[i]
    let neighbors = atomsToAtomsMap[i]
    switch atom.atomicNumber {
    case 1:
      guard neighbors.count == 1 else {
        fatalError("Incorrectly bonded hydrogen.")
      }
    case 6, 14, 32:
      guard neighbors.count == 4 else {
        fatalError("Incorrectly bonded carbon.")
      }
    case 16:
      guard neighbors.count == 2 else {
        fatalError("Incorrectly bonded sulfur.")
      }
    default:
      fatalError("Unexpected atom type.")
    }
  }
  
  topology.sort()
  
  // MARK: - Minimize
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  forceField.minimize(tolerance: 0.1)

  for atomID in topology.atoms.indices {
    let position = forceField.positions[atomID]
    topology.atoms[atomID].position = position
  }
  
  // MARK: - Return Atoms
  
  return topology.atoms
}
