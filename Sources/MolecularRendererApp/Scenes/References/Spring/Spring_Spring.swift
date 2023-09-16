//
//  Spring_Spring.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation
import MolecularRenderer
import HDL

struct Spring_Spring {
  var provider: any MRAtomProvider
  
  init() {
    let springLattice =
    Lattice<Cubic> {
      Material { .carbon }
      Bounds { 10 * h + 10 * k + 10 * l }
      
      Volume {
        Origin { 5 * h + 5 * k + 5 * l }
        Concave {
          for h_vector in [h, -h] {
            for k_vector in [k, -k] {
              Convex {
                Origin { -1 * (h_vector + k_vector) }
                Plane { h_vector + k_vector }
              }
            }
          }
        }
        
        Concave {
          Convex {
            Origin { -0.25 * l }
            Plane { +l }
          }
          for vector in [-k] {
            Convex {
              Origin { -vector * 0.5 }
              Plane { h + vector + l }
            }
          }
          Origin { 2 * l }
          Convex {
            Origin { 0.25 * l }
            Plane { -l }
          }
          for vector in [k, -k] {
            Convex {
              Origin { -vector * 0.5 }
              Plane { h + vector - l }
            }
          }
        }
        
        Concave {
          Convex {
            Origin { 0.25 * l }
            Plane { -l }
          }
          for vector in [h] {
            Convex {
              Origin { -vector * 0.5 }
              Plane { vector - k - l }
            }
          }
          
          Origin { -2 * l }
          Convex {
            Origin { -0.25 * l }
            Plane { +l }
          }
          for vector in [h, -h] {
            Convex {
              Origin { -vector * 0.5 }
              Plane { vector - k + l }
            }
          }
        }
        
        for vector in [l, -l] {
          Convex {
            Origin { 2 * vector }
            Plane { vector }
          }
        }
        for vector in [-h + k + l, -h - k + l] {
          Concave {
            Plane { +l }
            Origin { -h + vector }
            Plane { vector }
          }
        }
        for vector in [-h + k - l, h + k - l] {
          Concave {
            Plane { -l }
            Origin { k + vector }
            Plane { vector }
          }
        }
        
        Cut()
      }
    }
    let centers = springLattice._centers
    provider = ArrayAtomProvider(centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    })
    print(centers.count)
  }
}
