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
        
        // Stack two of these.
        func carveSpring() {
          for (h_index, h) in [h, -h].enumerated() {
            for (k_index, k) in [k, -k].enumerated() {
              for (l_index, l) in [l, -l].enumerated() {
                Concave {
                  Concave {
                    Origin { -0.25 * (h + k + l) }
                    Plane { h }
                    Plane { k }
                    Plane { l }
                  }
                  if (h_index + k_index + l_index) % 2 == 1 {
                    Origin { 0.25 * (h + k + l) }
                  }
                  Origin { -1.0 * k }
                  
                  Convex {
                    Convex {
                      Origin { 2 * (h + k + l) }
                      Plane { h + k + l }
                    }
                    Concave {
                      for axis in [h, k, l] {
                        Convex {
                          Origin { 0.5 * axis }
                          Plane { axis }
                        }
                      }
                    }
                    Concave {
                      Origin { 0.5 * (h + l) }
                      Plane { h }
                      Plane { l }
                    }
                    
                    if (h_index + k_index + l_index) % 2 == 1 {
                      Origin { -0.50 * (h + k + l) }
                    }
                    Concave {
                      Concave {
                        Origin { 1 * (h + k + l) }
                        for (first, second, third) in [
                          (h, k, l), (k, l, h), (l, h, k)
                        ] {
                          Convex {
                            Origin { 2 * (second + third) }
                            Plane { first - second - third }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        
        Concave {
          Convex {
            carveSpring()
          }
          for k in [k, -k] {
//            let
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
