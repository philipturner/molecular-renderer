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
    let rope = try! DiamondRope(height: 1.5, width: 1, length: 40)
    let ropeAtoms = rope.lattice._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    provider = ArrayAtomProvider(ropeAtoms)
    
    // Covalently weld some weights onto the ends.
    // Scene 1: a jig in the middle spinning around the rope like a spiral.
    // Scene 2: four jigs bending the rope into a Z.
    
    // There can be multiple of these jigs to play around with the rope in
    // different ways. Just make sure a single jig holds the rope correctly.
    let jigLattice = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds { 10 * h + 10 * k + 10 * l }
      
      Volume {
        Origin { 5 * h + 5 * k + 5 * l }
        Plane { +k }
        Cut()
      }
    }
    let jigAtoms = jigLattice._centers.map {
      MRAtom(origin: ($0 + [0, -5, 0]) * 0.357, element: 6)
    }
    provider = ArrayAtomProvider(ropeAtoms + jigAtoms)
  }
}
