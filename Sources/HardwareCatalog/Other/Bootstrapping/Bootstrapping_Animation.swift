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
      print("app start")
      
      let checkpoint0 = CACurrentMediaTime()
      let surface = Surface()
//      frames.append(surface.atoms)
      
      let checkpoint1 = CACurrentMediaTime()
//      var tripods: [Tripod] = []
//      let tripodPositions = Tripod.createPositions(radius: 58) // 38
//      for position in tripodPositions {
//        tripods.append(Tripod(position: position))
//      }
//      print("tripod atoms:", tripods.reduce(0) { $0 + $1.atoms.count })
//
      let checkpoint2 = CACurrentMediaTime()
      let probe = Probe()
//
      let checkpoint3 = CACurrentMediaTime()
      print("time 0 - 1:", checkpoint1 - checkpoint0)
      print("time 1 - 2:", checkpoint2 - checkpoint1)
      print("time 2 - 3:", checkpoint3 - checkpoint2)
//      frames[0] += probe.atoms
//      frames.append(surface.atoms + tripods.flatMap(\.atoms) + probe.atoms)
      
//      let tripod = Tripod(position: .zero)
//      frames[0] += tripod.atoms
      
      for frameID in 1..<1000 {
        let t = Float.sin(Float(frameID) / 50 + .pi / 2)
        let heightChange = Float(0.05) * t - 0.05
        
        let tripod = TripodWarp.global
          .createTripod(heightChange: heightChange)
        var frame = (surface.atoms + tripod.atoms).map {
          var copy = $0
          copy.origin.y -= 0 * heightChange
          return copy
        }
        frame += probe.atoms
        self.frames.append(frame)
      }
      
      // Ensure no nearby tripod collides with the AFM. If a tripod has its
      // moiety removed, that may or may not make it okay to come near again.
      //
      // Show the surface moving for the up-close part of the animation, then
      // the scanning probe moving for the bulk of the trajectory. Zoom back in
      // to the tip to show the finished product. When mechanosynthesizing onto
      // the build plate, the AFM is still the object that's moving. It can now
      // access the tripods in the rim of the area, which have much higher
      // density and require the sharper tip to handle.
      // - To pull off the "surface motion" effect in the most efficient way,
      //   keep the atoms for the tripods and surface always constant. Instead,
      //   shift the camera's origin to make it look like the AFM is still.
      //
      // Set up an array structure to efficiently hold the atom positions each
      // frame. Only the atoms that move this/last frame need to be mutated.
      // This means you should record the subranges that were mutated this
      // frame, so they can be reset at the start of the next frame.
    }
    
    // For the final animation, we may need a function for scripting the camera.
    func atoms(time: MRTime) -> [MRAtom] {
      if time.absolute.frames >= frames.count {
        return frames.last ?? []
      } else {
        return frames[time.absolute.frames]
      }
    }
  }
}
