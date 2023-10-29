//
//  Chapter12_Figure1.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

import Foundation
import HDL
import MolecularRenderer

extension Nanosystems.Chapter12 {
  // This figure will be a picture-perfect reproduction of Figure 1. The
  // simulation will be hosted in another stored property. The stacking
  // direction must be vertical to match the MIT thesis.
  struct Figure1/*: Figure3D*/ {
//    var a: Diamondoid
//    var b: Diamondoid
//    var c: Diamondoid
    var provider: any MRAtomProvider
    
    init() {
      provider = ArrayAtomProvider([MRAtom(origin: .zero, element: 6)])
      
      let rodLattice = Lattice<Hexagonal> { h, k, l in
        let h2k = h + 2 * k
        Bounds { 10 * h + 8 * h2k + 16 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 5 * h + 4 * h2k + 8 * l }
          
          for direction in [h, -h] {
            Convex {
              Origin { 2 * direction }
              Plane { direction }
            }
          }
          Convex {
            Origin { h2k }
            Plane { h2k }
          }
          for direction in [l, -l] {
            Concave {
              Origin { -h2k }
              Plane { -h2k }
              Convex {
                if direction.z == 1 {
                  Origin { 1.8 * direction }
                } else {
                  Origin { 2 * direction }
                }
                Plane { direction }
              }
            }
          }
          Convex {
            Origin { -3 * h2k }
            Plane { -h2k }
          }
          Replace { .empty }
        }
      }
      let rodAtoms = rodLattice.entities.map(MRAtom.init)
      var rodDiamondoid = Diamondoid(atoms: rodAtoms)
      provider = ArrayAtomProvider(rodDiamondoid.atoms)
      
      // Next, create the housing.
    }
  }
}
