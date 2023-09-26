//
//  Flywheel.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/26/23.
//

import Foundation
import MolecularRenderer
import HardwareCatalog
import HDL
import simd
import QuartzCore

struct Flywheel_Provider {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    let flywheel = Flywheel()
    fatalError("Not implemented.")
  }
}
