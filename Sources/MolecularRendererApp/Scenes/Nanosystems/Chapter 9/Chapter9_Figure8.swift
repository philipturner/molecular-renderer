//
//  Chapter9_Figure8.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Foundation
import MolecularRenderer
import simd

extension Nanosystems.Chapter9 {
  struct Figure8: Figure3D {
    var a: Diamondoid
    
    init() {
      // How we'll do this.
      // Generate a flat sheet of diamond.
      // Warp it around the X axis.
      // Adjust the atoms' distances from the center.
      // - around four different parameters to fine-tune
      // - not allowed to compress parallel to the axis, a nice constraint
      //   - actually, this might be analytically solvable with trigonometry
      // Get it working through trial and error.
      // Reposition so it's rotating around the Z axis instead.
      
      // New idea:
      // - Analytically solve for the offsets caused by warping around the axis.
      // - Procedurally generate the entire structure using those offsets.
      
      // Transform into the rotated coordinate space after making a mesh of
      // diamond along the (110) plane, and ensuring the non-warped version
      // looks correct.
      
      // Find the rotation angle, and scale the atoms along a certain axis. At
      // each position, the typical angle between atoms will be different. Try
      // to find a sweet spot (through trial and error) where both warped angles
      // are reasonably close to 109.5 degrees.
//      let separationAngle: Float = 2 * .pi / 32
      fatalError("Not implemented.")
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a]
    }
    
    var stackingDirection: SIMD3<Float> {
      SIMD3(0, -1, 0)
    }
  }
}
