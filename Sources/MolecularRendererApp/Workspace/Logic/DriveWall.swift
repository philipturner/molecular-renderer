//
//  DriveWall.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/11/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct DriveWallDescriptor {
  var dimensions: SIMD3<Int>?
  var patterns: [RampPattern] = []
  
  // The positions of all non-quaternary atoms, as a base64 string.
  var surfaceAtoms: String?
}

struct DriveWall: LogicSerialization {
  var rigidBody: MM4RigidBody
  
  init(descriptor: DriveWallDescriptor) {
    let lattice = Self.createLattice(descriptor: descriptor)
    let topology = Self.createTopology(lattice: lattice)
    let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    
    if let surfaceAtoms = descriptor.surfaceAtoms {
      var splitBefore: [Entity] = []
      for atomID in bulkAtomIDs {
        let atom = topology.atoms[Int(atomID)]
        splitBefore.append(atom)
      }
      
      let splitAfter = Serialization.deserialize(atoms: surfaceAtoms)
      rigidBody = Self.createRigidBody(
        bulkAtoms: splitBefore, surfaceAtoms: splitAfter)
    } else {
      rigidBody = Self.createRigidBody(topology: topology)
      minimize(bulkAtomIDs: bulkAtomIDs)
      
      let extracted = extractSurfaceAtoms(bulkAtomIDs: bulkAtomIDs)
      guard extracted.count == topology.atoms.count - bulkAtomIDs.count else {
        fatalError("Unexpected behavior.")
      }
      print(Serialization.serialize(atoms: extracted))
    }
  }
  
  static func createLattice(
    descriptor: DriveWallDescriptor
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
