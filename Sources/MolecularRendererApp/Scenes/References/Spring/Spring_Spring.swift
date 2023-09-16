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
          for hk_offset in [Float(-1.25), 0, 1.25] {
            for l_offset in [Float(-2.5), 0, 2.5] { Convex {
              if hk_offset == 0 {
                if l_offset != 0 {
                  return
                } else {
                  for l_vector in [l, -l] {
                    Convex {
                      Origin { 0.50 * l_vector }
                      Valley(h + k + l_vector) { l_vector }
                    }
                  }
                }
              } else {
                if hk_offset * l_offset < 0 {
                  return
                }
              }
              
              Origin { hk_offset * (h + k) }
              Origin { l_offset * l }
              for vector in [h + k, -h - k] { Convex {
                Origin { 0.75 * vector }
                Ridge(vector + l) { vector }
              } }
            } }
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
