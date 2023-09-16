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
    let springLattice = Lattice<Cubic> {
      Material { .carbon }
      Bounds { 10 * h + 10 * k + 10 * l }
      
      Volume {
        Origin { 5 * h + 5 * k + 5 * l }
        Concave {
          Plane { h + l }
          // TODO: Make an open 90 degree angle between two (100) planes, each
          // having a 135 degree angle betwen the (110) plane.
          for vector in [h + k + l, -h - k - l] {
            Convex {
              Origin { -vector * 0.5 }
              Plane { vector }
            }
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
