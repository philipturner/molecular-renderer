//
//  Rod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/23/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Rod {
  var topology = Topology()
  
  init(atoms: [Entity]) {
    topology.insert(atoms: atoms)
    passivate()
  }
  
  // Adds hydrogens and reorders the atoms for efficient simulation.
  mutating func passivate() {
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
