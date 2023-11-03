//
//  RippleCounter.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 11/3/23.
//

import Foundation
import HardwareCatalog
import HDL
import MolecularRenderer

// Create some logic gates in this file, then extract them to the hardware
// catalog once you want to instantiate them multiple times. Transfer the code
// from this file to the hardware catalog.

// 4-bit ripple counter using nanomechanical logic, combinational and serial
struct RippleCounter {
  var provider: any MRAtomProvider
  
  init() {
    // First step: create a board that's anchored in place using MM4 anchors,
    // but sufficiently deep to account for thermodynamic effects.
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 10 * h2k + 30 * l }
      Material { .elemental(.carbon) }
      
      // Create grooves for logic gates by calling Concave on the parent
      // lattice. This is an alternative form of CSG, as the Solid API from the
      // HDL is still unfinished.
    }
    let board = lattice.entities.map(MRAtom.init)
    self.provider = ArrayAtomProvider(board)
    
    // Another Lattice for the logic rods that go on the sliding positions.
    print(board.count)
    
//    fatalError("Not implemented.")
  }
}
