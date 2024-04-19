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
  //
  // - Create a piecewise function to only warp certain chunks of the structure,
  //   each at a slightly different center of curvature.
  
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 10 * h + 18 * k + 10 * l }
    Material { .elemental(.carbon) }
    
    func createPanels(offset: Float, direction: Float) {
      
    }
    
    // TODO: Replace each instance of 'h' with a series of one-atomic-layer
    // ledges.
    Volume {
      Concave {
        Convex {
          Origin { 1.5 * h }
          Plane { h }
        }
        Convex {
          Origin { 8 * k }
          Plane { -k }
        }
        Convex {
          Origin { 8.5 * h }
          Plane { -h }
        }
      }
      
      Concave {
        Convex {
          Origin { 1.5 * h }
          Plane { h }
        }
        Convex {
          Origin { 10 * k }
          Plane { k }
        }
        Convex {
          Origin { 8.5 * h }
          Plane { -h }
        }
      }
      
      Replace { .empty }
    }
  }
  
  return lattice.atoms
}
