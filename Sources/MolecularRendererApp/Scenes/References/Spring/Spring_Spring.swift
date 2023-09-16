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
      let numSections: Int = 3
      let sectionHeight: Int = 4
      do {
        let height = Float(14 + sectionHeight * (numSections - 1))
        Bounds { 10 * h + height * k + 10 * l }
      }
      
      func carveLargeSection(index largeSectionIndex: Int) {
        Origin { 5 * h + 7 * k + 5 * l }
        Origin { Float(largeSectionIndex * sectionHeight) * k }
        
        func carveSmallSection() {
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
            Convex {
              carveSmallSection()
            }
            for k in [k, -k] {
              Convex {
                Origin { 3 * k }
                Plane { k }
              }
            }
          }
          var l_vector: Vector<Cubic>
          var k_vector: Vector<Cubic>
          if largeSectionIndex == 0 {
            l_vector = l
            k_vector = k
          } else if largeSectionIndex == numSections - 1 {
            l_vector = -l
            k_vector = -k
          } else {
            return
          }
          Convex {
            Convex {
              Origin { -1 * k_vector }
              Ridge(h + l_vector + k_vector) { k_vector }
              Origin { -0.25 * k_vector }
              Ridge(h - l_vector + k_vector) { k_vector }
            }
            Convex {
              Origin { -7 * k_vector }
              Ridge(h - l_vector - k_vector) { -k_vector }
              Origin { -0.75 * k_vector }
              Ridge(h + l_vector - k_vector) { -k_vector }
            }
//            Concave {
//              Origin { -2 * k_vector }
//              Valley(h - l_vector - k_vector) { -k_vector }
//              Origin { -0.25 * k_vector }
//              Valley(h + l_vector - k_vector) { -k_vector }
//            }
          }
        }
        
        for slice in 0..<2 {
          if largeSectionIndex == 0 {
            if slice == 0 { continue }
          }
          if largeSectionIndex == numSections - 1 {
            if slice == 1 { continue }
          }
          Concave {
            let vector = (slice == 0) ? -k : k
            Origin { Float(sectionHeight / 2) * vector }
            Plane { vector }
          }
        }
      }
      
      Volume {
        Concave {
          for i in 0..<numSections {
            Convex {
              carveLargeSection(index: i)
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
