//
//  Bootstrapping_Animation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import HDL
import MolecularRenderer

// Approach: Herman 1999 + CBN 2023

extension Bootstrapping {
  struct Animation: MRAtomProvider {
    var frames: [[MRAtom]] = []
    
    init() {
      let surface = Surface()
      var tripods: [Tripod] = []
      
      let tripodPositions = Tripod.createPositions(radius: 38)
      for position in tripodPositions {
        tripods.append(Tripod(position: position))
      }
      frames.append(surface.atoms + tripods.flatMap(\.atoms))
      
      // Challenge: automatically choose a trajectory where the AFM doesn't
      // collide with any nearby tripods.
    }
    
    // For the final animation, we may need a function for scripting the camera.
    mutating func atoms(
      time: MolecularRenderer.MRTimeContext
    ) -> [MolecularRenderer.MRAtom] {
      if time.absolute.frames >= frames.count {
        return frames.last ?? []
      } else {
        return frames[time.absolute.frames]
      }
    }
  }
}
