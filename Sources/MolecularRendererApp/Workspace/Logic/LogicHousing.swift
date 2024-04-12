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
  var surfaceAtomPositions: String?
}

struct LogicHousing {
  var rigidBody: MM4RigidBody
  
  init(descriptor: LogicHousingDescriptor) {
    let lattice = Self.createLattice(descriptor: descriptor)
    let topology = Self.createTopology(lattice: lattice)
    
    if let surfaceAtomPositions = descriptor.surfaceAtomPositions {
      let split = Self.split(topology: topology)
      print(split.bulk.count, split.surface.count)
      
      // TODO: Make serialize() operate on the rigid body, instead of on the
      // atoms?
      
      rigidBody = Self.createRigidBody(topology: topology)
      minimize()
      
      var topology = Topology()
      var insertedAtoms: [Entity] = []
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
        insertedAtoms.append(entity)
      }
      topology.insert(atoms: insertedAtoms)
      topology = Serialization.reconstructBonds(
        topology: topology, quaternaryAtomIDs: [6])
      
      rigidBody = Self.createRigidBody(topology: topology)
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
}

// MARK: - Serialization

extension LogicHousing {
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
}
