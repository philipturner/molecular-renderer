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
        Bounds { 10 * h + 8 * h2k + 20 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 5 * h + 4 * h2k + 10 * l }
          
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
      rodDiamondoid.translate(offset: [
        Float(0.252 * 5.25),
        Float(0.437 * 1.25),
        Float(-0.412 * 4)
      ])
      
      // Next, create the housing.
      let housingLattice = Lattice<Hexagonal> { h, k, l in
        let h2k = h + 2 * k
        Bounds { 20 * h + 9 * h2k + 12 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 10 * h + 4 * h2k + 6 * l }
          
          Concave {
            for direction in [h2k, -h2k] {
              Convex {
                if direction.y > 0 {
                  Origin { 3 * direction }
                } else {
                  Origin { 2.5 * direction }
                }
                Plane { -direction }
              }
            }
            for direction in [h, -h] {
              Convex {
                if direction.x > 0 {
                  Origin { 4 * direction }
                } else {
                  Origin { 3.5 * direction }
                }
                Plane { -direction }
              }
            }
            for direction in [h * 2 + k, -h * 2 - k] {
              Convex {
                if direction.x > 0 {
                  Origin { 3 * direction }
                } else {
                  Origin { 2.5 * direction }
                }
                Plane { -direction }
              }
            }
            
            // Try doing a few Volume { } -> Replace { .empty } calls instead
            // of very complex Concave { } logic.
          }
          
          Replace { .empty }
        }
      }
      let housingAtoms = housingLattice.entities.map(MRAtom.init)
//      var housingDiamondoid = Diamondoid(atoms: housingAtoms)
//      housingDiamondoid.minimize()
      
      let allAtoms = rodDiamondoid.atoms + housingAtoms
//      let allAtoms = rodDiamondoid.atoms + housingDiamondoid.atoms
      print("Atom count: \(allAtoms.count)")
      provider = ArrayAtomProvider(allAtoms)
      
//      let simulator = MM4(diamondoids: [], fsPerFrame: <#T##Double#>)
    }
  }
}
