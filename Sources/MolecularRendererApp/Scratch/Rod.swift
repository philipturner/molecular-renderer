//
//  Rod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 2/25/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct RodDescriptor {
  var xIndex: Int?
  var yIndex: Int?
}

struct Rod {
  var topology = Topology()
  var xIndex: Int
  var yIndex: Int
  
  init(descriptor: RodDescriptor) {
    guard let xIndex = descriptor.xIndex,
          let yIndex = descriptor.yIndex else {
      fatalError("Descriptor was not complete.")
    }
    self.xIndex = xIndex
    self.yIndex = yIndex
    
    topology.atoms = createLattice().atoms
    alignAtoms()
    addHydrogens()
  }
  
  mutating func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      let length: Float = 20
      Bounds { length * h + 2 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 1.9 * l }
          Plane { l }
        }
        Convex {
          Origin { 1 * h2k }
          Plane { k - h }
        }
        Replace { .empty }
      }
    }
  }
  
  mutating func alignAtoms() {
    let diamondConstant = Constant(.square) { .elemental(.carbon) }
    for i in topology.atoms.indices {
      var position = topology.atoms[i].position
      position = SIMD3(position.z, position.y, position.x)
      position += diamondConstant * SIMD3(3.0, 2.5, 0)
      position.x += 0.030
      position.y -= 0.050
      topology.atoms[i].position = position
    }
    for i in topology.atoms.indices {
      var position = topology.atoms[i].position
      position.x += 8 * diamondConstant * Float(xIndex)
      position.y += 10 * diamondConstant * Float(yIndex)
      topology.atoms[i].position = position
    }
  }
  
  mutating func addHydrogens() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}
