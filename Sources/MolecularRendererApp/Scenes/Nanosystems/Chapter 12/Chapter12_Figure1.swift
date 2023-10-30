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
                  Origin { 1 * direction }
                }
                Plane { direction }
              }
            }
          }
          Convex {
            Origin { -4 * h2k }
            Plane { -h2k }
          }
          Replace { .empty }
        }
      }
      let rodAtoms = rodLattice.entities.map(MRAtom.init)
      var rodDiamondoid = Diamondoid(atoms: rodAtoms)
      provider = ArrayAtomProvider(rodDiamondoid.atoms)
      rodDiamondoid.translate(offset: [
        Float(0.252 * 7.25),
        Float(0.437 * 5.25),
        Float(-0.412 * 4)
      ])
      
      // Next, create the housing.
      let housingLattice = Lattice<Hexagonal> { h, k, l in
        let h2k = h + 2 * k
        Bounds { 20 * h + 13 * h2k + 12 * l }
        Material { .elemental(.carbon) }
        
        Volume {
          Origin { 12 * h + 8 * h2k + 6 * l }
          
          // TODO: Always remember to comment your HDL code. Otherwise, it's
          // almost impossible to understand when looking back on it.
          
          // Cut the initial block into an L-shape.
          //
          // There's a compiler bug preventing me from wrapping
          // "Origin { 2.8 * l } - Plane { l }" neatly in a shared scope.
          Concave {
            Origin { 2.8 * l - 3 * h2k }
            Plane { l }
            Plane { -h2k }
          }
          
          // Cut a cool chiseled shape around the first rod's housing.
          for direction in [-2 * h - k, h - k] {
            Concave {
              Origin { 2.8 * l }
              if direction.x > 0 {
                Origin { 4.0 * direction }
              } else {
                Origin { 3.5 * direction }
              }
              Plane { l }
              Plane { direction }
            }
          }
          for direction in [h * 2 + k, -h + k] {
            Convex {
              Origin { 5 * direction }
              Plane { direction }
            }
          }
          Concave {
            Origin { 2.8 * l - 6.5 * h }
            Plane { l }
            Plane { -h }
          }
          
          // Create the hole for the first rod to go through.
          Concave {
            for direction in [h2k, -h2k] {
              Convex {
                if direction.y > 0 {
                  Origin { 3 * direction }
                } else {
                  Origin { 3.5 * direction }
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
                if direction.y > 0 {
                  if direction.x > 0 {
                    Origin { 3 * direction }
                  }
                } else {
                  Origin { 3 * direction }
                }
                Plane { -direction }
              }
            }
            
            // Create the overhang that stops the first rod from falling out.
            //
            // It seems, the second rod needs to be placed far off-center. The
            // first rod doesn't move far enough for the second rod to run
            // through the middle.
            Volume {
              Concave {
                Origin { -0.5 * h2k }
                Plane { h2k }
                Origin { -2 * h }
                Plane { h + k }
              }
              Replace { .empty }
            }
            Volume {
              Concave {
                for direction in [l, -l] {
                  Convex {
                    if direction[2] > 0 {
                      Origin { 4 * direction }
                    } else {
                      Origin { 4.2 * direction }
                    }
                    Plane { -direction }
                  }
                }
              }
              Replace { .empty }
            }
          }
        }
      }
      let housingAtoms = housingLattice.entities.map(MRAtom.init)
      var housingDiamondoid = Diamondoid(atoms: housingAtoms)
      housingDiamondoid.fixHydrogens(tolerance: 0.08) { _ in true }
      housingDiamondoid.minimize()
      
      // TODO: Change the anchors, so none of them are close to the rod. This
      // simulation doesn't provide room for degrees of freedom in the housing
      // to hurt machine performance.
      rodDiamondoid.externalForce = [0, 0, -500]
      housingDiamondoid.anchors = [Bool](
        repeating: false, count: housingDiamondoid.atoms.count)
      let numAnchors = Int(Float(housingDiamondoid.atoms.count) / 40)
      for _ in 0..<numAnchors {
        let randomAtom = housingDiamondoid.atoms.indices.randomElement()!
        housingDiamondoid.anchors[randomAtom] = true
      }
      
//      let allAtoms = rodDiamondoid.atoms + housingAtoms
      let allAtoms = rodDiamondoid.atoms + housingDiamondoid.atoms
      print("Atom count: \(allAtoms.count)")
      provider = ArrayAtomProvider(allAtoms)
      
//      let simulator = MM4(diamondoids: [
//        rodDiamondoid, housingDiamondoid
//      ], fsPerFrame: 100)
//      simulator.simulate(ps: 10)
//      provider = simulator.provider
    }
  }
}
