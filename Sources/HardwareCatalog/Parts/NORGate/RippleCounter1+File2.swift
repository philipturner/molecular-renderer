//
//  RippleCounter+File2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 11/3/23.
//

import Foundation
import HDL
import MolecularRenderer

extension RippleCounter1 {
  func logicRod1() -> [MRAtom] {
    // There definitely seems to be a simpler way to get a vdW potential energy
    // surface with the same effect. Use some slanted planes. This will
    // unfortunately decrease the restoring force, but hopefully it will be
    // sufficient.
    //
    // Update: For the spring, use a clocked separation from a vdW bond on the
    // top of the rod. This allows the same clock motion to have massive
    // fan-out. And, retracting the clock rod will retract the other rods.
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 15 * h + 7 * h2k + 15 * l }
      Material { .elemental(.carbon) }
      
      // After getting this to work **at all**, cut some grooves in the side.
      // The grooves will make it want to go back to its original position on
      // the vdW potential energy surface.
      Volume {
        // Create a T shape.
        Concave {
          Origin { 4 * h + 3.5 * h2k }
          Plane { -h }
          Plane { -h2k }
        }
        Concave {
          Origin { 6 * h + 3.5 * h2k }
          Plane { h }
          Plane { -h2k }
        }
        
        // Cut off some bounds along X.
        Convex {
          Origin { 1 * h }
          Plane { -h }
        }
        Convex {
          Origin { 9 * h }
          Plane { h }
        }
        
        // Cut off some bounds along Y.
        Convex {
          Origin { 0.1 * h2k }
          Plane { -h2k }
        }
        Convex {
          Origin { 5 * h2k }
          Plane { h2k }
        }
        
        // Cutoff off some bounds along Z.
        Convex {
          Origin { 2 * l }
          Plane { -l }
        }
        Convex {
          Origin { 9.8 * l }
          Plane { l }
        }
        
        Replace { .empty }
      }
    }
    return lattice.entities.map(MRAtom.init)
  }
}
