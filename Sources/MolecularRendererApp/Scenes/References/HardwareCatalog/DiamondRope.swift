//
//  DiamondRope.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/25/23.
//

import Foundation
import MolecularRenderer
import HardwareCatalog
import HDL
import simd
import QuartzCore

struct DiamondRope_Provider {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    let rope = DiamondRope(height: 3, width: 2, length: 11)
    let ropeAtoms = rope.lattice._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    provider = ArrayAtomProvider(ropeAtoms)
  }
}
