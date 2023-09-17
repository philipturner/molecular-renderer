//
//  Spring_Springboard.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation
import MolecularRenderer
import HDL
import simd
import QuartzCore

struct Spring_Springboard {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    var spring = Spring_Spring()
    spring.diamondoid.translate(
      offset: 0.357 * [Float(6), Float(0), Float(6)])
    print()
    print("springboard")
    
    let springboardLattice = Lattice<Cubic> {
      Material { .carbon }
      Bounds { 12 * h + 10 * k + 12 * l }
      
      Volume {
        Origin { 6 * h + 5 * k + 6 * l }
        
        Concave {
          func cutLower() {
            Convex {
              Origin { -1 * k }
              Plane { -k }
            }
            Concave {
              Plane { -h }
              Plane { -l }
              Plane { -k }
              Origin { -1.5 * (h + l) }
              Plane { -h - l }
            }
          }
          Convex {
            cutLower()
            Concave {
              Origin { 5.5 * k }
              Valley(h - l - k) { -k }
              Origin { -0.50 * k - 0.25 * (h + l) }
              Valley(h + l - k) { -k }
            }
          }
          Convex {
            cutLower()
            Concave {
              Origin { 4.5 * k }
              Valley(h - l - k) { -k }
              Valley(h + l - k) { -k }
            }
            Concave {
              Origin { -3.5 * k }
              Valley(h + l + k) { +k }
              Origin { -0.75 * k }
              Valley(h - l + k) { +k }
            }
          }
          func cutBack() {
            Convex {
              Origin { 2.75 * (-h - k - l) }
              Plane { -h - k - l }
            }
          }
          Convex {
            cutBack()
            Origin { +k }
            Convex {
              Origin { -1.75 * k }
              Plane { -h + k + l }
              Plane { h + k - l }
            }
            Convex {
              Origin { -3 * k }
              Origin { -0.5 * (h + l) }
              Plane { h + k + l }
              
              Origin { -1.5 * k }
              Plane { h - k + l }
            }
            Convex {
              Origin { -4.5 * k }
              Plane { -h - k + l }
              Plane { h - k - l }
            }
          }
          Convex {
            cutBack()
            Origin { -2.5 * h - 2.5 * l }
            Convex {
              Origin { 0.25 * (-h + l) }
              Plane { -h + l }
            }
            Convex {
              Origin { 0.25 * (h + l) }
              Plane { h + l }
            }
            Convex {
              Origin { 0.25 * (h - l) }
              Plane { h - l }
            }
            Convex {
              Origin { -2.5 * k }
              Plane { -k }
            }
          }
        }
      
        Convex {
          Origin { 7 * k }
          Ridge(h + l + k) { k }
          Origin { 0.25 * k }
          Ridge(h - l + k) { k }
        }
        Convex {
          Origin { -6 * k }
          Plane { -h - k + l }
          Plane { h - k - l }
        }
        Concave {
          Convex {
            Origin { -1 * k }
            Plane { +k }
          }
          Convex {
            Origin { -1.5 * k }
            Ridge(-h - k + l) { -k }
          }
          Convex {
            Origin { 4.5 * k }
            Valley(-h - k + l) { -k }
          }
          Convex {
            Origin { -4.25 * k }
            Origin { -0.25 * (h + l) }
            Ridge(-h - k - l) { -k }
          }
        }
        Concave {
          Convex {
            Origin { -1 * k }
            Plane { +k }
            Plane { +h }
          }
          Origin { 1.25 * (h - k + l) }
          Plane { h - k + l }
          Origin { -1.25 * (h + k + l) }
          Plane { h + k + l }
        }
        Concave {
          Convex {
            Origin { -1 * k }
            Plane { +k }
          }
          Convex {
            Origin { -1.5 * k }
            Ridge(-h - k + l) { -k }
          }
          Convex {
            Origin { -4.25 * k }
            Origin { -0.25 * (h + l) }
            Plane { -h - k - l }
          }
        }
        Concave {
          Origin { 3.5 * k }
          Valley(h + l + k) { +k }
          Origin { -0.75 * k }
          Valley(h - l + k) { +k }
        }
        Concave {
          Convex {
            Origin { -2 * k }
            Plane { -h - k + l }
          }
          Convex {
            Origin { -1 * k }
            Plane { +k }
          }
        }
        Concave {
          Convex {
            Origin { -2 * k }
            Plane { h - k - l }
          }
          Convex {
            Origin { -k }
            Plane { +k }
          }
        }
        
        Cut()
      }
    }
    spring.diamondoid.translate(
      offset: [0.65, 0.65, 0.65] + [1, -1, 1])
    
    let springboardCarbons = springboardLattice._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    provider = ArrayAtomProvider(spring.diamondoid.atoms + springboardCarbons)
    print("carbon atoms:", springboardCarbons.count)
    
    var diamondoid = Diamondoid(atoms: springboardCarbons)
    diamondoid.minimize()
    spring.diamondoid.minimize()
    
    spring.diamondoid.rotate(angle: simd_quatf(
      angle: 45 * .pi / 180, axis: normalize(SIMD3(-1, 0, 1))))
    
    provider = ArrayAtomProvider(spring.diamondoid.atoms + diamondoid.atoms)
    print("total atoms:", diamondoid.atoms.count)
    
    let direction = normalize(SIMD3<Float>(-1, 1, -1))
    spring.diamondoid.linearVelocity = 0.050 * direction
    
    // Definitely include this simulation in the animation. Show the two
    // crystolecules easing in/out to their new locations, including the
    // rotation of the joint. Later, we'll need to use MD to assemble the
    // entire structure properly.
//    let simulator = _Old_MM4(
//      diamondoids: [diamondoid, spring.diamondoid!], fsPerFrame: 20)
//    simulator.simulate(ps: 40)
//    provider = simulator.provider
  }
}
