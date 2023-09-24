//
//  Spring_Projectile.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation
import MolecularRenderer
import HDL
import simd
import QuartzCore

// Shape the projectile so that landing disperses as little vdW energy as
// possible (don't want it to take the ring with it!). Make it poke into the
// four housings sticking out of the top, and perfectly align the trajectory to
// make that happen. Use the crystolecule assembly from the springboard to
// measure where the protrusions should be placed.
struct Spring_Projectile {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
    
//    _Parse.verbose = true
//    let projectileLattice = Lattice<Cubic> { x, y, z in
//      try! _Parse { "/Users/philipturner/Desktop/file.swift" }
//    }
//    let projectileCarbons = projectileLattice._centers.map {
//      MRAtom(origin: $0 * 0.357, element: 6)
//    }
//    provider = ArrayAtomProvider(projectileCarbons)
  }
}
