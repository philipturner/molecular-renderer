//
//  Flywheel.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/26/23.
//

import Foundation
import HDL

public struct Flywheel {
  public var centers: [SIMD3<Float>]
  
  public init() {
    // Wheel also needs a matching interface (like ties in a knot), otherwise
    // the connector will just slide.
    let connector = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds { 10 * h + 10 * k + 10 * l }
      
      Volume {
        for widthDirection in [Float(1), Float(-1)] { Convex {
          Origin { widthDirection * 0.25 * (h - l) }
          Plane { widthDirection * (h - l) }
        } }
        Convex {
          Origin { 6 * k }
          Plane { +k }
        }
        Concave {
          Origin { 1.5 * k }
          Plane { +k }
          Origin { 3 * k }
          Plane { -k }
          Origin { 1.5 * (h + l) }
          Plane { h + l }
        }
        Cut()
      }
    }
    let lattice = try! DiamondRope(height: 1.5, width: 1, length: 20).lattice
    let solid = Solid { h, k, l in
      Copy { lattice }
      
      // Connect two opposing connectors to form a beam that spans the diameter.
      // Then, cross two diameters at a 90 degree angle, offset by 0.25 lattice
      // cells along the Z direction.
      Affine {
        Copy { connector }
        Translate { -2.25 * k }
      }
    }
    
    func deduplicate(_ atoms: [SIMD3<Float>]) -> [SIMD3<Float>] {
      var newAtoms: [SIMD3<Float>] = []
      for i in 0..<atoms.count {
        let atom = atoms[i]
        if newAtoms.contains(where: {
          let delta = $0 - atom
          return sqrt((delta * delta).sum()) < 0.001
        }) {
          continue
        } else {
          newAtoms.append(atom)
        }
      }
      return newAtoms
    }
    
    centers = solid._centers
  }
}
