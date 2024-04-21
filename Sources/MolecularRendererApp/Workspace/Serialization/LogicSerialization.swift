//
//  LogicSerialization.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/13/24.
//

import Foundation
import HDL
import MM4
import Numerics

protocol LogicSerialization {
  var rigidBody: MM4RigidBody { get set }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody
}

extension LogicSerialization {
  // Extract the atoms that should be fixed during minimization.
  static func extractBulkAtomIDs(topology: Topology) -> [UInt32] {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    
    var bulkAtomIDs: [UInt32] = []
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let atomElement = Element(rawValue: atom.atomicNumber)!
      let atomRadius = atomElement.covalentRadius
      
      let neighborIDs = atomsToAtomsMap[atomID]
      var carbonNeighborCount: Int = .zero
      var correctBondCount: Int = .zero
      
      for neighborID in neighborIDs {
        let neighbor = topology.atoms[Int(neighborID)]
        let neighborElement = Element(rawValue: neighbor.atomicNumber)!
        let neighborRadius = neighborElement.covalentRadius
        if neighbor.atomicNumber == 6 {
          carbonNeighborCount += 1
        }
        
        let delta = atom.position - neighbor.position
        let bondLength = (delta * delta).sum().squareRoot()
        let expectedBondLength = atomRadius + neighborRadius
        if bondLength / expectedBondLength < 1.1 {
          correctBondCount += 1
        }
      }
      
      if carbonNeighborCount == 4, correctBondCount == 4 {
        bulkAtomIDs.append(UInt32(atomID))
      }
    }
    return bulkAtomIDs
  }
  
  // Finds the surface geometry with an accuracy of 0.1 zJ.
  mutating func minimize(bulkAtomIDs: [UInt32]) {
    var forceFieldParameters = rigidBody.parameters
    for atomID in bulkAtomIDs {
      forceFieldParameters.atoms.masses[Int(atomID)] = .zero
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = forceFieldParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = rigidBody.positions
    forceField.minimize(tolerance: 0.1)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = rigidBody.parameters
    rigidBodyDesc.positions = forceField.positions
    rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

extension LogicSerialization {
  // Constructs the rigid body from deserialized build products.
  static func createRigidBody(
    bulkAtoms: [Entity], surfaceAtoms: [Entity]
  ) -> MM4RigidBody {
    var topology = Topology()
    topology.insert(atoms: bulkAtoms)
    topology.insert(atoms: surfaceAtoms)
    Serialization.reconstructBonds(
      topology: &topology, quaternaryAtomIDs: [6])
    return Self.createRigidBody(topology: topology)
  }
  
  // Extract the atoms that moved during minimization.
  func extractSurfaceAtoms(bulkAtomIDs: [UInt32]) -> [Entity] {
    let bulkAtomSet = Set(bulkAtomIDs)
    
    var surfaceAtoms: [Entity] = []
    for atomID in rigidBody.parameters.atoms.indices {
      if bulkAtomSet.contains(UInt32(atomID)) {
        continue
      }
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
      surfaceAtoms.append(entity)
    }
    return surfaceAtoms
  }
}
