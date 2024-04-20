//
//  LogicHousing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct LogicHousingDescriptor {
  var dimensions: SIMD3<Int>?
  var patterns: [HolePattern] = []
}

struct LogicHousing {
  var topology: Topology
  
  init(descriptor: LogicHousingDescriptor) {
    let checkpoint0 = Date()
    let lattice = Self.createLattice(descriptor: descriptor)
    let checkpoint1 = Date()
    topology = Self.createTopology(lattice: lattice)
//    let checkpoint2 = Date()
//    rigidBody = Self.createRigidBody(topology: topology)
//    let checkpoint3 = Date()
//    
//    let interval01 = checkpoint1.timeIntervalSince(checkpoint0) * 1e3
//    let interval12 = checkpoint2.timeIntervalSince(checkpoint1) * 1e3
//    let interval23 = checkpoint3.timeIntervalSince(checkpoint2) * 1e3
//    
//    print()
//    print("compile time overview:")
//    print("- lattice:", String(format: "%.1f", interval01), " ms")
//    print("- topology:", String(format: "%.1f", interval12), " ms")
//    print("- rigidBody:", String(format: "%.1f", interval23), " ms")
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
}
