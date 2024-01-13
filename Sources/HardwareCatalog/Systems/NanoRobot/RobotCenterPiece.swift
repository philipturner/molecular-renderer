//
//  RobotCenterPiece.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/12/24.
//

import HDL
import MM4

struct RobotCenterPiece {
  var topology = Topology()
  var parameters: MM4Parameters?
  
  init() {
    compilationPass0()
    compilationPass1()
    compilationPass2()
    compilationPass3()
  }
  
  // Carve out some shapes in the walls. A future compilation pass will fuse
  // the backboard together, creating a solid piece.
  mutating func compilationPass0() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 11 * h + 8 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      func carveOuterShell() {
        Convex {
          Concave {
            Convex {
              Origin { -4 * h }
              Plane { h }
            }
            Convex {
              Origin { 5 * h }
              Plane { -h }
            }
          }
          Origin { 5 * h2k }
          Plane { -h2k }
        }
      }
      
      func carveInnerBump() {
        Convex {
          Convex {
            Origin { 2 * h2k }
            Origin { 0.25 * h }
            Plane { k }
            Plane { k + h }
          }
          Convex {
            Origin { 1.5 * h }
            Plane { h }
          }
          Convex {
            Origin { -0.5 * h }
            Plane { -h }
          }
        }
      }
      
      Volume {
        Origin { 5 * h + 1 * l }
        Plane { -l }
        
        Convex {
          Origin { 3.5 * l }
          Plane { l }
        }
        
        Concave {
          carveOuterShell()
          carveInnerBump()
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func compilationPass1() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 11 * h + 8 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 0.8 * l }
          Plane { l }
        }
        Replace { .empty }
        
        Convex {
          Origin { 0.2 * l }
          Plane { -l }
        }
        Replace { .atom(.silicon) }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func compilationPass2() {
    let radius = Element.carbon.covalentRadius * 2
    let matches = topology.match(
      topology.atoms, algorithm: .absoluteRadius(1.5 * radius))
    
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        insertedBonds.append(SIMD2(UInt32(i), UInt32(j)))
      }
    }
    topology.insert(bonds: insertedBonds)
    
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var removedAtoms: [UInt32] = []
    for i in topology.atoms.indices {
      if atomsToAtomsMap[i].count <= 1 {
        removedAtoms.append(UInt32(i))
      }
    }
    topology.remove(atoms: removedAtoms)
    
    let orbitals = topology.nonbondingOrbitals()
    let chBondLength = Element.carbon.covalentRadius +
    Element.hydrogen.covalentRadius
    
    var insertedAtoms: [Entity] = []
    insertedBonds = []
    for i in topology.atoms.indices {
      let carbon = topology.atoms[i]
      for orbital in orbitals[i] {
        let position = carbon.position + orbital * chBondLength
        let hydrogen = Entity(position: position, type: .atom(.hydrogen))
        let hydrogenID = topology.atoms.count + insertedAtoms.count
        let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
        insertedAtoms.append(hydrogen)
        insertedBonds.append(bond)
      }
    }
    topology.insert(atoms: insertedAtoms)
    topology.insert(bonds: insertedBonds)
    topology.sort()
  }
}

extension RobotCenterPiece {
  mutating func compilationPass3() {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.bonds = topology.bonds
    paramsDesc.atomicNumbers = topology.atoms.map {
      if $0.atomicNumber == 1 { return 1 }
      else { return 6 }
    }
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    for i in topology.atoms.indices {
      if topology.atoms[i].atomicNumber == 14 {
        parameters.atoms.masses[i] = 0
      }
    }
    self.parameters = parameters
  }
}
