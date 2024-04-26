//
//  AxlePart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/25/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct AxlePart {
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 40 * h + 40 * k + 40 * l }
      Material { .elemental(.carbon) }
      
      // Trim away the back side, to prevent overlap with the sheet part.
      Volume {
        Origin { 4 * l }
        Plane { -l }
        Replace { .empty }
      }
      
      // Trim a cylinder pointing toward <110>.
      Volume {
        Origin { 10 * l }
        
        let eigenvector0 = l
        let eigenvector1 = (-h + k) / Float(2).squareRoot()
        let radius: Float = 5
        
        for sectorID in 0..<180 {
          let θ = Float(sectorID) * 2 * (Float.pi / 180)
          let coord0 = radius * Float.cos(θ)
          let coord1 = radius * Float.sin(θ)
          
          Convex {
            Origin { coord0 * eigenvector0 }
            Origin { coord1 * eigenvector1 }
            Plane { coord0 * eigenvector0 + coord1 * eigenvector1 }
          }
        }
        
        Replace { .empty }
      }
      
      // Clean up the faces.
      Volume {
        Convex {
          Origin { 7 * k }
          Plane { -h - k }
        }
        Convex {
          Origin { 40 * h + 33 * k }
          Plane { h + k }
        }
        Replace { .empty }
      }
    }
  }
}
