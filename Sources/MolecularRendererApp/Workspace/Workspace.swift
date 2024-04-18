import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Stick with cubic diamond for this, despite the warping issue.
  // - Keep the cylinder, but shrink it.
  // - Superimpose an H structure, then warp into a strained shell.
  // - Check the radius of curvature and curl of protrusions with Ge dopants.
  // - Create a piecewise function to only warp certain chunks of the structure,
  //   each at a slightly different center of curvature.
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 10 * k + 10 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 5 * h + 5 * k }
      
      for thetaDegrees in 0..<180 {
        let angle = Float(2 * thetaDegrees) * .pi / 180
        let direction = SIMD3(Float.cos(angle), Float.sin(angle), 0)
        
        Convex {
          Origin { 5 * direction }
          Plane { direction }
        }
      }
      
      Replace { .empty }
    }
  }
  
  return lattice.atoms
}
