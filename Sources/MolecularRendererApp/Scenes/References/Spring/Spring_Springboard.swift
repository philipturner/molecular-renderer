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
    
    let housingLattice = Lattice<Cubic> {
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
    
#if false
    spring.diamondoid.translate(
      offset: [0.65, 0.65, 0.65] + [1, -1, 1])
#endif
    let housingCarbons = housingLattice._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    provider = ArrayAtomProvider(
      spring.diamondoid.atoms + housingCarbons)
    print()
    print("housing")
    print("carbon atoms:", housingCarbons.count)
    
#if false
    var housing = Diamondoid(atoms: housingCarbons)
    housing.minimize()
    spring.diamondoid.minimize()
    
    spring.diamondoid.rotate(angle: simd_quatf(
      angle: 45 * .pi / 180, axis: normalize(SIMD3(-1, 0, 1))))
    
    provider = ArrayAtomProvider(spring.diamondoid.atoms + housing.atoms)
    print("total atoms:", housing.atoms.count)
#endif
    
    // Definitely include this simulation in the animation. Show the two
    // crystolecules easing in/out to their new locations, including the
    // rotation of the joint. Later, we'll need to use MD to assemble the
    // entire structure properly.
#if false
    let direction = normalize(SIMD3<Float>(-1, 1, -1))
    spring.diamondoid.linearVelocity = 0.050 * direction
    
    //    let simulator = _Old_MM4(
    //      diamondoids: [housing, spring.diamondoid!], fsPerFrame: 20)
    //    simulator.simulate(ps: 40)
    //    provider = simulator.provider
#endif
    
    // Animate the creation of this connector and its merging into the housing
    // instances via CSG.
    let connector1 = Lattice<Cubic> {
      Material { .carbon }
      let width: Float = 4
      let height: Float = 7
      Bounds { width * h + height * k + width * l }
      
      Volume {
        Ridge(h - k - l) { -k }
        Concave {
          Origin { Float(width / 2) * (h + l) + height * k }
          Convex {
            Origin { -0.75 * k }
            Ridge(h + k - l) { +k }
          }
          Convex {
            Origin { -3.5 * k }
            Valley(h + k + l) { +k }
          }
        }
        Concave {
          Origin { 1 * k }
          Ridge(h - k - l) { -k }
          Origin { 1 * k }
          Ridge(h + k - l) { +k }
        }
        Origin { Float(width / 2) * (h + l) }
        for vector in [h + l, -h - l] { Convex {
          Convex {
            Origin { 1.5 * vector }
            Plane { vector }
          }
          Concave {
            Origin { 1.25 * vector }
            Plane { vector }
            Origin { 2 * k }
            Plane { +k }
          }
        } }
        
        Cut()
      }
    }
    
    // Eventually, this will change to the `Copy` initializer of
    // `Lattice<Basis>`, so that h/j/k unit vectors may be used.
    let dualHousingSolid = Solid {
      Copy { housingLattice }
      Affine {
        Copy { housingLattice }
        
        // TODO: Method to encapsulate origin modifications to a specific
        // scope when operating on solids or lattices?
        Origin { 5 * h + 5 * l }
        Rotate { 0.5 * k }
        Translate { -5 * (h + l) }
      }
      Affine {
        Copy { connector1 }
        Translate { 0.5 * h + 2 * k + 0.5 * l }
      }
    }
    
    let dualHousingCarbons = dualHousingSolid._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    
    print("")
    print("dual housing")
    print("carbon atoms:", dualHousingCarbons.count)
    spring.diamondoid.translate(
      offset: 0.357 * [Float(-0.125), Float(0), Float(-0.125)])
    provider = ArrayAtomProvider(
      spring.diamondoid.atoms + dualHousingCarbons)
    
#if true
    spring.diamondoid.translate(
      offset: 0.357 * [Float(0.125), Float(0), Float(0.125)])
    spring.diamondoid.translate(
      offset: [0.65, 0.65, 0.65] + [1, -1, 1])
    spring.diamondoid.minimize()
    
    var dualHousing = Diamondoid(atoms: dualHousingCarbons)
    var springs: [Diamondoid] = [spring.diamondoid]
    
    let springSpeed: Float = 0.100
    do {
      var springCopy = springs[0]
      var com = springCopy.createCenterOfMass()
      com -= dualHousing.createCenterOfMass()
      com.y = 0
      springCopy.translate(offset: -2 * com)
      springs.append(springCopy)
      
      for i in 0..<2 {
        let angle: Float = (i == 0) ? 45 : -45
        springs[i].rotate(angle: simd_quatf(
          angle: angle * .pi / 180, axis: normalize(SIMD3(-1, 0, 1))))
        
        let direction = normalize(
          i == 0 ? SIMD3<Float>(-1, 1, -1) : SIMD3<Float>(1, 1, 1))
        springs[i].linearVelocity = springSpeed * direction
      }
    }
    dualHousing.minimize()
#endif
    
    provider = ArrayAtomProvider(
      springs[0].atoms + springs[1].atoms + dualHousing.atoms)
    print("total atoms:", dualHousing.atoms.count)
    
#if true
    do {
      print()
      print("spring =", springs[0].atoms.count, "atoms")
      print("dual housing =", dualHousing.atoms.count, "atoms")
      
      let sceneAtoms = 2 * springs[0].atoms.count + dualHousing.atoms.count
      print("2 x spring + housing =", sceneAtoms, "atoms")
    }
    
    // Measure the entire system's total momentum, then correct it by giving
    // the dual housing a velocity. Print the velocity assigned to the housing.
    do {
      let springMomentum = springs.reduce(SIMD3<Float>.zero) {
        $0 + $1.createMass() * $1.linearVelocity!
      }
      let housingMomentum = -springMomentum
      dualHousing.linearVelocity = housingMomentum / dualHousing.createMass()
      
      print()
      print("conservation of momentum")
      print("spring speed: \(Int(springSpeed * 1000)) m/s")
      print(
        "spring y velocity: \(Int(springSpeed * sqrt(1.0 / 3) * 1000)) m/s")
      print(
        "housing y velocity: \(Int(dualHousing.linearVelocity!.y * 1000)) m/s")
    }
    
    // Make another simulation to ensure both springs lock into the housing
    // correctly.
    // TODO
    
    #endif
    
    // TODO: A fourth (unplanned for) component type that bridges the gap
    // of 4 instances of connectors between 2 springs. Clicks into place in
    // a way that's a bit difficult for the final piece, but makes a virtually
    // unbreakable structure via geometric constraints.
    //
    // This project will go way over atom budget, but the awesomeness of the
    // idea shown above will be worth it.
  }
}
