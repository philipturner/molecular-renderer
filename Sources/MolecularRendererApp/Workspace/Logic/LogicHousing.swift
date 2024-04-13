//
//  LogicHousing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/11/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct LogicHousingDescriptor {
  var dimensions: SIMD3<Int>?
  var patterns: [HolePattern] = []
  
  // The positions of all non-quaternary atoms, as a base64 string.
  var surfaceAtoms: String?
}

struct LogicHousing {
  var rigidBody: MM4RigidBody
  
  init(descriptor: LogicHousingDescriptor) {
    let lattice = Self.createLattice(descriptor: descriptor)
    let topology = Self.createTopology(lattice: lattice)
    
    if let surfaceAtoms = descriptor.surfaceAtoms {
      let splitBefore = Self.split(topology: topology)
      let splitAfter = Serialization.deserialize(string: surfaceAtoms)
      rigidBody = Self.createRigidBody(
        bulkAtoms: splitBefore.bulk, surfaceAtoms: splitAfter)
    } else {
      rigidBody = Self.createRigidBody(topology: topology)
      minimize()
    }
  }
  
  static func createLattice(
    descriptor: LogicHousingDescriptor
  ) -> Lattice<Cubic> {
    guard let dimensions = descriptor.dimensions else {
      fatalError("Descriptor was not complete.")
    }
    
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds {
        Float(dimensions.x) * h +
        Float(dimensions.y) * k +
        Float(dimensions.z) * l
      }
      Material { .elemental(.carbon) }
      
      for pattern in descriptor.patterns {
        Volume {
          pattern(h, k, l)
        }
      }
    }
    return lattice
  }
  
  static func createTopology(lattice: Lattice<Cubic>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology.insert(atoms: lattice.atoms)
    reconstruction.compile()
    reconstruction.topology.sort()
    return reconstruction.topology
  }
  
  static func createRigidBody(topology: Topology) -> MM4RigidBody {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
}

// MARK: - Serialization

// TODO: Move all of this into a protocol for serializing logic components.

extension LogicHousing {
  mutating func minimize() {
    // Prevent the bulk atoms from moving.
    var forceFieldParameters = rigidBody.parameters
    for atomID in forceFieldParameters.atoms.indices {
      let centerType = forceFieldParameters.atoms.centerTypes[atomID]
      if centerType == .quaternary {
        forceFieldParameters.atoms.masses[atomID] = .zero
      }
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
  
  // Splits the topology into bulk and surface atoms.
  static func split(
    topology: Topology
  ) -> (bulk: [Entity], surface: [Entity]) {
    let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
    var bulkAtoms: [Entity] = []
    var surfaceAtoms: [Entity] = []
    
    for atomID in topology.atoms.indices {
      let atom = topology.atoms[atomID]
      let neighborIDs = atomsToAtomsMap[atomID]
      var carbonNeighborCount: Int = .zero
      
      for neighborID in neighborIDs {
        let neighbor = topology.atoms[Int(neighborID)]
        if neighbor.atomicNumber == 6 {
          carbonNeighborCount += 1
        }
      }
      
      if carbonNeighborCount == 4 {
        bulkAtoms.append(atom)
      } else {
        surfaceAtoms.append(atom)
      }
    }
    return (bulkAtoms, surfaceAtoms)
  }
  
  // Extracts the surface atoms for serialization.
  func extractSurfaceAtoms() -> [Entity] {
    var surfaceAtoms: [Entity] = []
    var forceFieldParameters = rigidBody.parameters
    for atomID in forceFieldParameters.atoms.indices {
      let centerType = forceFieldParameters.atoms.centerTypes[atomID]
      if centerType == .quaternary {
        // This is a bulk atom.
      } else {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
        surfaceAtoms.append(entity)
      }
    }
    return surfaceAtoms
  }
  
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
}
