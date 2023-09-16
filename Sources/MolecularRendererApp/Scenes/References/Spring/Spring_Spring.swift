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
      Bounds { 10 * x + 10 * y + 10 * z }
      
      Volume {
        Origin { 5 * x + 5 * y + 5 * z }
        Concave {
          Plane { x + y }
          Plane { x + y + z }
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
