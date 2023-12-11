//
//  Bootstrapping_Animation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import MolecularRenderer

extension Bootstrapping {
  struct Animation: MRAtomProvider {
    var frames: [[MRAtom]] = []
    
    init() {
      let surface = Surface()
      
      // Place a tripod directly at the center.
      let tripod = Tripod(position: [0, 0, 0])
      frames.append(surface.atoms + tripod.atoms)
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
