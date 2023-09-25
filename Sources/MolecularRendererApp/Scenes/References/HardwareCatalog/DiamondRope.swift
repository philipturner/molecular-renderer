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
    let rope = DiamondRope()
    fatalError("Not implemented.")
  }
}
