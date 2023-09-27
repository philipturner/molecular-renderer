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
  
  init() {
    let flywheel = Flywheel()
    let centers = flywheel.centers.map { $0 * 0.357 }
    provider = ArrayAtomProvider(centers.map {
      MRAtom(origin: $0, element: 6)
    })
    
//    let diamondoid = Diamondoid(carbonCenters: centers)
    print((provider as! ArrayAtomProvider).atoms.count)
//    print(diamondoid.atoms.count)
  }
}
