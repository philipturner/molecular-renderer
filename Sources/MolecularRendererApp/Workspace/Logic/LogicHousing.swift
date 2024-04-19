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

struct LogicHousing: GenericPart {
  var rigidBody: MM4RigidBody
  
  init(descriptor: LogicHousingDescriptor) {
    let lattice = Self.createLattice(descriptor: descriptor)
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
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
}
