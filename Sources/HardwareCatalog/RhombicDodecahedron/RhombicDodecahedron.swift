//
//  RhombicDodecahedron.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/25/23.
//

import Foundation
import HDL

public struct RhombicDodecahedron {
  public var lattice: Lattice<Cubic>
  
  /// - Parameter width: To avoid stray methyl carbons, a value produced by the formulas `4n + 1` or `4n + 2` is encouraged. Otherwise, explicitly trim off the stray methyl group. In the near future, the part will be changed to remove stray carbons, without creating a `V2` part.
  public init(width: Int) {
    lattice = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds { Float(width) * h + Float(width) * k + Float(width) * l }
      
      Volume {
        do {
          // Bypass the Swift compiler being unable to type-check this.
          let originVector =
          Float(width) / 2 * h +
          Float(width) / 2 * k +
          Float(width) / 2 * l
          Origin { originVector }
        }
        for widthDirection in [Float(1), Float(-1)] {
          Convex {
            Origin { widthDirection * Float(width) / 2 * h }
            Ridge(widthDirection * h + l) { widthDirection * h }
            Ridge(widthDirection * h + k) { widthDirection * h }
          }
        }
        for heightDirection in [Float(1), Float(-1)] {
          Convex {
            Origin { heightDirection * Float(width) / 2 * k }
            Ridge(heightDirection * k + l) { heightDirection * k }
          }
        }
        
        Cut()
      }
    }
  }
}
