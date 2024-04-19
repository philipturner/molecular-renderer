//
//  DesignIteration2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

#if false

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
    
    // Try switching over to hexagonal diamond, with (111) faces. Try something
    // new, and use P dopants at rotating interfaces.
    // - minimizes the expansion of axial thickness, because P is surface and
    //   Ge is bulk
    // - Ge can still be used for weights of the flywheel
    // - can still use two-fold symmetry
    //
    // The gears will be perpendicular to a plane with the 'h2k' and 'l'
    // vectors, which is a bit unfamiliar. The housing part of the bearing
    // can be cubic diamond.
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


#endif
