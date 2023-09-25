//
//  DiamondRope.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/25/23.
//

import HDL

/// TODO: Proper description.
public struct DiamondRope {
  public var lattice: Lattice<Cubic>
  
  /// - Parameter height: Measures the cross-section, typically 1-2 unit cells.
  /// - Parameter width: Measures the cross-section, typically 1-2 unit cells.
  /// - Parameter length: Measures the distance between two ends of the rope, typically several dozen unit cells. This is the number of cells along a diagonal (TODO: explain in more detail).
  public init(height: Int, width: Int, length: Int) {
    lattice = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds {
        Float(length) * h +
        Float(height) * k +
        Float(length) * l
      }
      
      // This needs to automatically prevent invalid carbon surfaces from
      // being exposed.
      Volume {
        do {
          // Bypass the Swift compiler being unable to type-check this.
          let originVector =
          Float(length) / 2 * h +
          Float(height) / 2 * k +
          Float(length) / 2 * l
          Origin { originVector }
        }
        Convex {
          Origin { Float(width) / 2 * (-h + l) }
          Plane { -h + l }
        }
        Convex {
          Origin { Float(width) / 2 * (h - l) }
          Plane { h - l }
        }
        Cut()
      }
    }
  }
}
