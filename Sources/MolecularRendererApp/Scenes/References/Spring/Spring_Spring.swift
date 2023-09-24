//
//  Spring_Spring.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation
import MolecularRenderer
import HDL
import simd
import QuartzCore

struct Spring_Spring {
  var provider: any MRAtomProvider
  var diamondoid: Diamondoid!
  
  init() {
    let springLattice = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      let numSections: Int = 2
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
              Origin { -6 * k_vector }
              Ridge(h - l_vector - k_vector) { -k_vector }
              Origin { -0.75 * k_vector }
              Ridge(h + l_vector - k_vector) { -k_vector }
            }
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
    print()
    print("spring")
    print("carbon atoms:", centers.count)
    
    // Show the hydrogens being added, using the same exponential
    // materialization technique (likely e^{-t^2} instead of e^{-t}; that
    // converges faster and has an ease-in-out shape).
    // - Achieved by having a very low dropout probability, but each frame
    //   running a large number of random number generations (on the atoms that
    //   haven't already (de)-materialized, to save compute cost). The number of
    //   tests increases proportionally the amount of time that has passed.
    var diamondoid = Diamondoid(atoms: centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    })
    diamondoid.translate(offset: -diamondoid.createCenterOfMass())
    self.diamondoid = diamondoid
    provider = ArrayAtomProvider(diamondoid.atoms)
    
    // Show the number of atoms in the animation, as minimizing the atom count
    // is important to engineering with limited compute power.
    print("total atoms:", diamondoid.atoms.count)
    
    // Record several frames of the minimization, make it part of the animation.
    #if false
    do {
      print("energy minimization: 8 x 0.5 ps")
      let start = CACurrentMediaTime()
      diamondoid.minimize()
      let end = CACurrentMediaTime()
      print("\(diamondoid.atoms.count) atoms")
      print("simulated in \(String(format: "%.1f", end - start)) seconds")
    }
    #endif
    var otherCopy = diamondoid
    
    // Make this testing part of the animation; it was a component of
    // nanomechanical design. Animate the creation of the copy (via exponential
    // decay like materialization) and the translation from the world origin to
    // the new position.
    diamondoid.translate(offset: [0, Float(-10) * 0.357, 0])
    
    var copy = diamondoid
    diamondoid.translate(offset: [0, Float(0.5) * 0.357, 0])
    copy.translate(offset: [0, Float(20) * 0.357, 0])
    copy.translate(offset: [0, Float(-0.5) * 0.357, 0])
    
    let linearSpeed: Float = Float(800) / 1000
    diamondoid.linearVelocity = [0, linearSpeed / 2, 0]
    copy.linearVelocity = [0, -linearSpeed / 2, 0]
    
    // Find how the diamondoid responds to a collision with a copy.
    // Display "400 m/s, 20 ps \n simulated in ..."
    // Attempt a second time, showing how higher linear velocity causes
    // different behavior.
    // Display "800 m/s, 10 ps \n simulated in..."
    #if false
    do {
      let numPicoseconds: Double = 10
      print("\(Int(linearSpeed * 1000)) m/s, \(Int(numPicoseconds)) ps")
      let start = CACurrentMediaTime()
      let simulator = _Old_MM4(diamondoids: [diamondoid, copy], fsPerFrame: 20)
      simulator.simulate(ps: numPicoseconds)
      provider = simulator.provider
      let end = CACurrentMediaTime()
      print("\(2 * diamondoid.atoms.count) atoms")
      print("simulated in \(String(format: "%.1f", end - start)) seconds")
    }
    #endif
    
    // Find how the diamondoid responds to its own rotational velocity.
    // Display "0.25 rad/ps (400 m/s), 20 ps \n simulated in ..."
    // Attempt a second time, showing how higher angular velocity causes
    // different behavior.
    // Display "0.50 rad/ps (800 m/s, 20 ps \n simulated in ..."
    #if false
    do {
      let numPicoseconds: Double = 10
      let angularSpeed: Float = 0.50
      let maxX = otherCopy.atoms.max(by: { $0.x < $1.x})!.x
      let maxZ = otherCopy.atoms.max(by: { $0.z < $1.z})!.z
      otherCopy.angularVelocity = simd_quatf(
        angle: angularSpeed, axis: [0, 1, 0])
      
      let linearSpeed = max(maxX, maxZ) * angularSpeed
      print("\(angularSpeed) rad/ps (\(Int(linearSpeed * 1000)) m/s),  \(Int(numPicoseconds)) ps")
      
      let start = CACurrentMediaTime()
      let simulator = _Old_MM4(diamondoid: otherCopy, fsPerFrame: 20)
      simulator.simulate(ps: numPicoseconds)
      provider = simulator.provider
      let end = CACurrentMediaTime()
      print("\(diamondoid.atoms.count) atoms")
      print("simulated in \(String(format: "%.1f", end - start)) seconds")
    }
    #endif
  }
}
