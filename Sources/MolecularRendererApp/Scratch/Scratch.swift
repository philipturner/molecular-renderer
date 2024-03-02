// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Create and simulate a small model of graphene.
  let graphene = Graphene()
  return graphene.topology.atoms
}

struct Graphene {
  var topology = Topology()
  var anchors: [UInt32] = []
  
  init() {
    let lattice = createLattice()
    topology.insert(atoms: lattice.atoms)
    
    adjustLatticeAtoms()
    removeCenterMarker()
    addHydrogens()
    removeAnchorMarkers()
  }
  
  mutating func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 2 * h + 2 * h2k + 1 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.3 * l }
          Plane { l }
        }
        Convex {
          Origin { 1 * h + 1.75 * h2k }
          Plane { k - h }
          Plane { k + 2 * h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Replace { .empty }
      }
      
      Volume {
        Origin { h + 0.8 * h2k }
        Concave {
          var directions: [SIMD3<Float>] = []
          directions.append(h)
          directions.append(h2k)
          directions.append(-h)
          directions.append(-h2k)
          for direction in directions {
            Convex {
              Origin { 0.3 * direction }
              Plane { -direction }
            }
          }
        }
        Replace { .atom(.gold) }
      }
      
      Volume {
        Origin { h + 0.625 * h2k }
        
        var directions: [SIMD3<Float>] = []
        directions.append(h2k)
        directions.append(-k + h)
        directions.append(-k - 2 * h)
        for direction in directions {
          Convex {
            Origin { 0.55 * direction }
            Plane { direction }
          }
        }
        Replace { .atom(.silicon) }
      }
    }
  }
  
  // Center the lattice at the origin, and scale it to the graphene lattice
  // constant.
  mutating func adjustLatticeAtoms() {
    var goldPosition: SIMD3<Float>?
    for atom in topology.atoms {
      if atom.atomicNumber == 79 {
        goldPosition = atom.position
      }
    }
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position -= goldPosition!
      atom.position.z = 0
      topology.atoms[atomID] = atom
    }
    
    let grapheneConstant: Float = 2.45 / 10
    let lonsdaleiteConstant = Constant(.hexagon) { .elemental(.carbon) }
    let scaleFactor = grapheneConstant / lonsdaleiteConstant
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      atom.position *= scaleFactor
      topology.atoms[atomID] = atom
    }
  }
  
  // Transmute the gold atom to carbon.
  mutating func removeCenterMarker() {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 79 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
  }
  
  // Add hydrogens to the perimeter of the graphene flake.
  mutating func addHydrogens() {
    let searchRadius = 2.1 * Element.carbon.covalentRadius
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(searchRadius))
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in matches.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp2)
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      for orbital in orbitals[atomID] {
        // Source: MM4/TinkerParameters
        let chBondLength: Float = 1.1010 / 10
        let position = atom.position + chBondLength * orbital
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(atomID), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
  }
  
  // Mark the anchors and transmute the silicon atoms to carbon.
  mutating func removeAnchorMarkers() {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      let map = atomsToAtomsMap[atomID]
      if map.count == 1 {
        let otherID = Int(map[0])
        let otherAtom = topology.atoms[otherID]
        if otherAtom.atomicNumber == 14 {
          anchors.append(UInt32(atomID))
        }
      }
    }
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      if atom.atomicNumber == 14 {
        atom.atomicNumber = 6
      }
      topology.atoms[atomID] = atom
    }
  }
}
