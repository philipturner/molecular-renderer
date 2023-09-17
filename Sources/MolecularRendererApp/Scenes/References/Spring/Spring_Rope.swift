//
//  Spring_Rope.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/17/23.
//

import Foundation
import MolecularRenderer
import HDL
import simd
import QuartzCore

struct Spring_Rope {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  // Might not be necessary for constructing a larger diamond housing, but
  // something interesting to try (and reduces atom count).
  init() {
    // Use a 2x2 diamond rod rope, with a buckle. Make it wrap around the stuff
    // to bind together, make another mechanism to lock the buckle in place. Use
    // elastic pressure tugging on the ropes to keep the buckle in place.
    //
    // Another rope wraps around the perimeter, keeping the springs from falling
    // out horizontally.
    //
    // Do some experiments to test how easily such a rope will bend, which
    // buckle geometries are good.
    fatalError("Not implemented.")
  }
}
