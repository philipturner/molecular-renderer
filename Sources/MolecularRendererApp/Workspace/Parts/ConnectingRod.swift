//
//  ConnectingRod.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct ConnectingRod {
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 30 * h + 6 * k + 3 * l }
      Material { .elemental(.carbon) }
    }
  }
}
