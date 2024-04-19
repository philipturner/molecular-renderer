//
//  DriveWall.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct DriveWallDescriptor {
  var dimensions: SIMD3<Int>?
  var patterns: [RampPattern] = []
}

struct DriveWall {
  var rigidBody: MM4RigidBody
  
  init(descriptor: DriveWallDescriptor) {
    let lattice = Self.createLattice(descriptor: descriptor)
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
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
