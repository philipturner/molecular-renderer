//
//  Bootstrapping_Animation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/10/23.
//

import HDL
import MolecularRenderer
import QuartzCore

// Approach: Herman 1999 + CBN 2023

extension Bootstrapping {
  struct Animation: MRAtomProvider {
    var frames: [[MRAtom]] = []
    
    init() {
      let checkpoint0 = CACurrentMediaTime()
      let surface = Surface()
      let checkpoint1 = CACurrentMediaTime()
      var tripods: [Tripod] = []
      let checkpoint2 = CACurrentMediaTime()
      let probe = Probe()
      let checkpoint3 = CACurrentMediaTime()
      
      print("time 0 - 1:", checkpoint1 - checkpoint0)
      print("time 1 - 2:", checkpoint2 - checkpoint1)
      print("time 2 - 3:", checkpoint3 - checkpoint2)
      
      let tripodPositions = Tripod.createPositions(radius: 29)
      for position in tripodPositions {
        tripods.append(Tripod(position: position))
      }
      frames.append(surface.atoms + tripods.flatMap(\.atoms) + probe.atoms)
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
