//
//  Surface.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics

// Si-H bond length: 1.483 Å (MM4)
// Si-Cl bond length: 2.029 Å (xTB)
// Cl-Cl bond length: 2.017 Å (xTB)

struct Surface {
  var topology: Topology
  
  init() {
    let lattice = Self.createLattice()
    topology = Self.createTopology(lattice: lattice)
  }
  
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * h + 10 * h2k + 3 * l }
      Material { .elemental(.silicon) }
    }
  }
  
  static func createTopology(lattice: Lattice<Hexagonal>) -> Topology {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    shift(topology: &topology)
    return topology
  }
}

extension Surface {
  private static func shift(topology: inout Topology) {
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.x, -position.z, position.y)
      
      // Offset by a multiple of the lattice constant.
      let latticeConstant = Constant(.hexagon) { .elemental(.silicon) }
      position.x -= latticeConstant * 5
      position.z -= latticeConstant * 5 * Float(3).squareRoot()
      
      atom.position = position
      topology.atoms[atomID] = atom
    }
  }
}
