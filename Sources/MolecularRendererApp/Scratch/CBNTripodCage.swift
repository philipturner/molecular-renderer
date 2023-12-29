//
//  CBNTripodCage.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/29/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

struct CBNTripodCage: CBNTripodComponent {
  var topology: Topology
  
  init() {
    self.topology = Topology()
    
    compilationPass0()
  }
  
  mutating func compilationPass0() {
    let atoms = createLattice()
    topology.insert(atoms: atoms)
  }
  
  mutating func compilationPass1() {
    // Hydrogenate the lattice. Create CHO groups at the methyl sites. The
    // oxygens should point outward to minimize the chance the interfere with
    // the symmetry of the minimized structure.
  }
}

extension CBNTripodCage {
  static let xtbOptimizedStructure: String = ""
}
