//
//  TestRod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/30/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

#if false
struct TestRod {
  var rigidBody: MM4RigidBody
  
  init(rod: Rod) {
    // Create the MM4 parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = rod.topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = rod.topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Create the rigid body and center it.
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = rod.topology.atoms.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    rigidBody.centerOfMass = .zero
    
    // Since the principal axes have a degenerate eigenspace, we must manually
    // rotate each class of logic rod.
    // rigidBody.rotate(angle: .pi / 2, axis: SIMD3(0, 1, 0)) // x-oriented
    // rigidBody.rotate(angle: .pi / 2, axis: SIMD3(-1, 0, 0)) // y-oriented
    // z-oriented does not require rotations
  }
}
#endif

struct TestRod {
  var topology = Topology()
  var rigidBody: MM4RigidBody!
  
  init() {
    createLattice()
    createBulkAtomBonds()
    createHydrogens()
    sortAtoms()
    createRigidBody()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 20 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Concave {
          Origin { 1 * h2k }
          Plane { h2k }
          Origin { 1 * h }
          Plane { k - h }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
}

extension TestRod {
  mutating func createBulkAtomBonds() {
    // Fetch a data structure that maps atoms to their neighbors.
    let matches = topology.match(topology.atoms)
    
    // Create bulk atom bonds.
    var insertedBonds: [SIMD2<UInt32>] = []
    for i in topology.atoms.indices {
      for j in matches[i] where i < j {
        let bond = SIMD2(UInt32(i), UInt32(j))
        insertedBonds.append(bond)
      }
    }
    topology.insert(bonds: insertedBonds)
  }
  
  mutating func createHydrogens() {
    // Fetch the directions where hydrogens should point.
    let orbitals = topology.nonbondingOrbitals(hybridization: .sp3)
    
    // Create hydrogen atoms and hydrogen bonds.
    var insertedAtoms: [Entity] = []
    var insertedBonds: [SIMD2<UInt32>] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      guard atom.atomicNumber == 6 else {
        continue
      }
      
      for orbital in orbitals[atomID] {
        // Bond length acquired from MM4 parameters.
        // Units: Å -> nm
        let chBondLength: Float = 1.1120 / 10
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
  
  mutating func sortAtoms() {
    // Sort the atoms for efficient simulation.
    topology.sort()
  }
  
  mutating func createRigidBody() {
    // Create the MM4 parameters.
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Freeze the carbons ~2 atomic layers inside the bounding volume.
    let neighbors = topology.map(.atoms, to: .atoms)
    for atomID in topology.atoms.indices {
      let centerType = parameters.atoms.centerTypes[atomID]
      guard centerType == .quaternary else {
        continue
      }
      
      var closeToSurface = false
      for neighborID in neighbors[atomID] {
        let centerType = parameters.atoms.centerTypes[Int(neighborID)]
        if centerType != .quaternary {
          closeToSurface = true
        }
      }
      if closeToSurface {
        continue
      }
      
      parameters.atoms.masses[atomID] = 0
    }
    
    // Create the rigid body, but don't modify its position.
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}
