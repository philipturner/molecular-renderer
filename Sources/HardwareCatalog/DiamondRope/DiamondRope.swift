//
//  DiamondRope.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/25/23.
//

import Foundation
import HDL

public struct DiamondRope {
  public var lattice: Lattice<Cubic>
  
  /// - Parameter height: Measures the cross-section, typically 1-2 unit cells. Must have .5 in the decimal place.
  /// - Parameter width: Measures the cross-section, typically 1-2 unit cells. Must be divisible by 0.5.
  /// - Parameter length: Measures the distance between two ends of the rope, typically several dozen unit cells. This is the number of cells along a diagonal (TODO: explain in more detail).
  public init(height: Float, width: Float, length: Int) throws {
    struct _Error: LocalizedError {
      var description: String
    }
    guard height > 0, width > 0, length > 0 else {
      throw _Error(description: "Width, height, or length was not positive.")
    }
    guard height - height.rounded(.down) == 0.5 else {
      throw _Error(description: "Height '\(height)' did not have .5 in the decimal place.")
    }
    guard width.remainder(dividingBy: 0.5) == 0 else {
      throw _Error(description: "Width '\(width)' was not divisible by 0.5.")
    }
    
    lattice = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds {
        Float(length + 2) * h +
        height.rounded(.up) * k +
        Float(length + 2) * l
      }
      
      // This needs to automatically prevent invalid carbon surfaces from
      // being exposed.
      Volume {
        Convex {
          Origin { height * k }
          Plane { +k }
        }
        do {
          // Bypass the Swift compiler being unable to type-check this.
          let originVector =
          Float(length + 2) / 2 * h +
          height / 2 * k +
          Float(length + 2) / 2 * l
          Origin { originVector }
        }
        for lengthDirection in [Float(1), Float(-1)] {
          Convex {
            Origin { lengthDirection * Float(length) / 2 * (h + l) }
            Plane { lengthDirection * (h + l) }
          }
        }
        for widthDirection in [Float(1), Float(-1)] {
          Convex {
            Origin { widthDirection * width / 2 * (-h + l) }
            Plane { widthDirection * (-h + l) }
          }
        }
        for heightDirection in [Float(1), Float(-1)] {
          Convex {
            Origin { heightDirection * height / 2 * k }
            Ridge(heightDirection * k - h + l) { heightDirection * k }
          }
        }
        Cut()
      }
    }
  }
}
