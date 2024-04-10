//
//  Surface.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/10/24.
//

import Foundation
import HDL
import MM4
import Numerics

// A partially-hydrogenated partially-chlorinated silicon surface.
//
// Accepts a programmable 'Lattice<Cubic>' and generates the passivated surface
// from it. The current form of the code relies on a built-in
// 'createLattice()', but we'll likely need to make it more flexible in the
// future.
struct Surface {
  static func createLattice() -> Lattice<Cubic> {
    fatalError("Not implemented.")
  }
}
