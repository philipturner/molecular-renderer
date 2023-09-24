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
    
    let housingLattice = Lattice<Cubic> { h, k, l in
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
    let connector1 = Lattice<Cubic> { h, k, l in
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
    let dualHousingSolid = Solid { h, k, l in
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
    
#if false
    spring.diamondoid.translate(
      offset: 0.357 * [Float(0.125), Float(0), Float(0.125)])
    spring.diamondoid.translate(
      offset: [0.65, 0.65, 0.65] + [1, -1, 1])
    spring.diamondoid.minimize()
    
    var dualHousing = Diamondoid(atoms: dualHousingCarbons)
    var springs: [Diamondoid] = [spring.diamondoid]
    
    // Show how the joining succeeded at 300 m/s. Shorten the simulation to
    // omit the part where it falls apart.
    let springSpeed: Float = 0.300
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
    
    provider = ArrayAtomProvider(
      springs[0].atoms + springs[1].atoms + dualHousing.atoms)
    print("total atoms:", dualHousing.atoms.count)
#endif
    
#if false
    // Make another simulation to ensure both springs lock into the housing
    // correctly.
    do {
      let numPicoseconds: Double = 40
      print()
      print("\(Int(springSpeed * 1000)) m/s, \(numPicoseconds) ps")
      let sceneAtoms = 2 * springs[0].atoms.count + dualHousing.atoms.count
      print("2 x spring + housing =", sceneAtoms, "atoms")
      
      let start = CACurrentMediaTime()
      let simulator = _Old_MM4(
        diamondoids: springs + [dualHousing], fsPerFrame: 20)
      simulator.simulate(ps: numPicoseconds)
      provider = simulator.provider
      let end = CACurrentMediaTime()
      print("simulated in \(String(format: "%.1f", end - start)) seconds")
    }
#endif
    
    // Assemble the entire structure without a jig.
    do {
      #if true
      spring.diamondoid.translate(
        offset: 0.357 * [Float(0), Float(0.125), Float(0)])
      
      var dualHousing = Diamondoid(atoms: dualHousingCarbons)
      dualHousing.minimize()
      var dualHousings: [Diamondoid] = [dualHousing]
      var springs: [Diamondoid] = [spring.diamondoid]
      
      let housingCenterOfMass = dualHousing.createCenterOfMass()
      let springCenterOfMass = spring.diamondoid.createCenterOfMass()
      var spring2Delta = 2 * (housingCenterOfMass - springCenterOfMass)
      spring2Delta.y = 0
      var spring2 = springs[0]
      spring2.translate(offset: spring2Delta)
      springs.append(spring2)
      
      let housing2Rotation = simd_quatf(angle: -90 * .pi / 180, axis: [0, 1, 0])
      var housing2Delta = -spring2Delta / 2
      var housing2 = dualHousings[0]
      housing2.translate(offset: housing2Delta)
      housing2.rotate(angle: housing2Rotation)
      
      housing2Delta = housing2Rotation.act(housing2Delta)
      housing2.translate(offset: 2 * housing2Delta)
      housing2.rotate(angle: housing2Rotation)
      
      housing2Delta = housing2Rotation.act(housing2Delta)
      housing2.translate(offset: housing2Delta)
      dualHousings.append(housing2)
      
      var systemCenter = (dualHousings[0].createCenterOfMass() +
                          dualHousings[1].createCenterOfMass()) / 2
      systemCenter.y = springs[0].createCenterOfMass().y
      var newHousings = dualHousings
      var newSprings = springs
      
      for i in 0..<newHousings.count {
        var diamondoid = newHousings[i]
        let currentDelta = diamondoid.createCenterOfMass() - systemCenter
        
        let systemRotation1 = simd_quatf(
          angle: 180 * .pi / 180, axis: normalize(SIMD3<Float>(1, 0, 1)))
        let systemRotation2 = simd_quatf(
          angle: 90 * .pi / 180, axis: normalize(SIMD3<Float>(0, 1, 0)))
        var newDelta = systemRotation1.act(currentDelta)
        newDelta = systemRotation2.act(newDelta)
        
        diamondoid.rotate(angle: systemRotation1)
        diamondoid.rotate(angle: systemRotation2)
        diamondoid.translate(offset: -currentDelta + newDelta)
        newHousings[i] = diamondoid
      }
      dualHousings += newHousings
      
      for i in 0..<newSprings.count {
        var diamondoid = newSprings[i]
        let currentDelta = diamondoid.createCenterOfMass() - systemCenter
        
        let systemRotation1 = simd_quatf(
          angle: 180 * .pi / 180, axis: normalize(SIMD3<Float>(0, 1, 0)))
        let newDelta = systemRotation1.act(currentDelta)
        
        diamondoid.rotate(angle: systemRotation1)
        diamondoid.translate(offset: -currentDelta + newDelta)
        newSprings[i] = diamondoid
      }
      springs += newSprings
      
      let providerAtoms = (dualHousings + springs).flatMap { $0.atoms }
      provider = ArrayAtomProvider(providerAtoms)
      print("4 x spring + 4 x housing =", providerAtoms.count)
      #endif
      
      #if false
      print("energy minimization: 8 x 0.5 ps")
      var start = CACurrentMediaTime()
      let simulator = _Old_MM4(
        diamondoids: dualHousings + springs, fsPerFrame: 20)
      let emptyVelocities: [SIMD3<Float>] = Array(
        repeating: .zero, count: providerAtoms.count)
      
      // Energy-minimize the entire system.
      var positions: [SIMD3<Float>] = []
      var angularSpeedInRadPs: Float = -1
      var linearSpeedInNmPs: Float = -1
      for i in 0..<8 {
        simulator.simulate(ps: 0.5, minimizing: true)
        if i == 7 {
          let masses = simulator.repartitionedMasses
          positions = simulator.provider.states.last!.map(\.origin)
          
          var centerOfMass_d = (0..<providerAtoms.count).reduce(
            SIMD3<Double>.zero
          ) {
            $0 + masses[$1] * SIMD3<Double>(positions[$1])
          }
          centerOfMass_d /= masses.reduce(0, +)
          let centerOfMass = SIMD3<Float>(centerOfMass_d)
          print("center of mass:", centerOfMass)
          
          let largestRadius = positions.map { length($0 - centerOfMass) }.max()!
          print("largest radius:", largestRadius)
          angularSpeedInRadPs = 0.160 // rad/ps
          linearSpeedInNmPs = largestRadius * angularSpeedInRadPs
          
          let angularVelocity = simd_quatf(
            angle: angularSpeedInRadPs, axis: [0, 1, 0])
          let w = angularVelocity.axis * angularVelocity.angle
          simulator.provider.reset()
          simulator.thermalize(velocities: positions.map {
            let r = $0 - centerOfMass
            return cross(w, r)
          })
        } else {
          simulator.provider.reset()
          simulator.thermalize(velocities: emptyVelocities)
        }
      }
      var end = CACurrentMediaTime()
      print("simulated in \(String(format: "%.1f", end - start)) seconds")
      
      // In the animation, show the reverse of this falling apart at 800
      // meters per second. Replay the simulation backwards to show how the
      // structure can be constructed, with a final drift toward the state from
      // CAD (pre-minimization). Then, fill in the bridges connecting each pair
      // of dual housings.
      let numPicoseconds: Double = 50
      print("\(angularSpeedInRadPs) rad/ps (\(Int(linearSpeedInNmPs * 1000)) m/s), \(Int(numPicoseconds)) ps")
      start = CACurrentMediaTime()
      simulator.simulate(ps: numPicoseconds)
      provider = simulator.provider
      end = CACurrentMediaTime()
      print("simulated in \(String(format: "%.1f", end - start)) seconds")
      #endif
      
      #if true
      // A diamond lattice will appear superimposed over the structure. After
      // carving out the half cross section, it slides away in a direction that
      // doesn't collide with any other matter. Completed, hydrogenated rings
      // approach from above/side and slide into place.
      let ringLattice = Lattice<Cubic> { h, k, l in
        Material { .carbon }
        Bounds { 32 * h + 7 * k + 32 * l }
        
        Volume {
          Origin { 16 * h + 16 * l }
          Plane { h }
          
          Convex {
            Origin { 14.5 * k }
            Ridge(h + k + l) { +k }
          }
          
          Concave {
            Convex {
              Convex {
                Origin { 3.5 * k }
                Ridge(h - k - l) { -k }
              }
              Convex {
                Origin { 6.75 * k }
                Ridge(h + k - l) { +k }
              }
              Convex {
                Origin { 6 * k }
                Valley(h - k + l) { -k }
              }
              Convex {
                Origin { 4 * k }
                Valley(h + k + l) { +k }
              }
              Convex {
                Origin { -5.25 * k }
                Ridge(h - k + l) { -k }
              }
            }
            Convex {
              Convex {
                Origin { 4.5 * k }
                Ridge(h - k + l) { -k }
                Origin { 3 * k }
                Ridge(h + k + l) { +k }
              }
              Convex {
                Origin { -0.5 * k }
                Ridge(h - k - l) { -k }
              }
              Convex {
                Origin { 9.25 * k }
                Ridge(h + k - l) { +k }
              }
              Convex {
                Origin { 2.5 * k }
                Valley(h + k - l) { +k }
              }
            }
            Convex {
              Origin { 4.25 * (-h + l) + 4 * k }
              Convex {
                Origin { 2 * (-h + l) + -4 * k }
                Ridge(h - k - l) { -k }
              }
              Convex {
                Origin { 2.25 * k }
                Ridge(h + k - l) { +k }
              }
              Convex {
                Origin { 4.25 * (-h + l) + 2 * k }
                Convex {
                  Origin { 2 * k }
                  Ridge(h + k + l) { +k }
                }
                Convex {
                  Origin { -2 * k }
                  Ridge(h - k + l) { -k }
                }
              }
            }
            Convex {
              Convex {
                Origin { 2.5 * k }
                Ridge(h - k + l) { -k }
                Origin { 2 * k }
                Valley(h + k + l) { +k }
                Origin { 4 * k }
                Ridge(h + k + l) { +k }
              }
              Concave {
                Convex {
                  Origin { -0.5 * k }
                  Ridge(h - k - l) { -k }
                }
                Convex {
                  Origin { 13 * k }
                  Valley(h - k - l) { -k }
                }
                Convex {
                  Origin { 6.75 * k }
                  Valley(h - k + l) { -k }
                }
              }
            }
            Convex {
              Convex {
                Origin { 6 * (-h + l) + 5.5 * k }
                Plane { h + k - l }
              }
              Convex {
                Origin { 17 * k }
                Valley(h - k - l) { -k }
              }
              Convex {
                Origin { 18.75 * k }
                Ridge(h + k - l) { +k }
              }
              Convex {
                Origin { -11.5 * k }
                Ridge(h - k - l) { -k }
              }
            }
          }
          Convex {
            Origin { 18.75 * k }
            Ridge(h + k - l) { +k }
          }
          Convex {
            Origin { -11.5 * k }
            Ridge(h - k - l) { -k }
          }
          Concave {
            Origin { 5 * (-h + l) + 4.5 * k }
            Origin { -2 * k }
            Convex {
              Origin { -2.25 * k }
              Valley(h + k + l) { +k }
            }
            Convex {
              Origin { 3.00 * k }
              Valley(h - k + l) { -k }
            }
            Convex {
              Plane { -h + k + l }
              Origin { 0.5 * k }
              Plane { -h - k + l }
            }
            Convex {
              Origin { 2.50 * k }
              Plane { -h - k + l }
            }
          }
          Concave {
            Origin { 5 * (-h + l) + 4.5 * k }
            Convex {
              Origin { -0.25 * k }
              Valley(h + k + l) { +k }
            }
            Convex {
              Origin { 0 * (-h + l) + 2.50 * k }
              Plane { -h + k + l }
            }
          }
          Concave {
            Origin { 1 * (-h + l) + 4.5 * k }
            Origin { -2 * k }
            Convex {
              Origin { -2.25 * k }
              Valley(h + k + l) { +k }
            }
            Convex {
              Origin { 3.00 * k }
              Valley(h - k + l) { -k }
            }
            Convex {
              Origin { 2.50 * k }
              Plane { h - k - l }
            }
          }
          Convex {
            Origin { -7.25 * k }
            Ridge(h - k + l) { -k }
          }
          
          Cut()
        }
      }
      let ringSolid = Solid { h, k, l in
        Copy { ringLattice }
        Affine {
          Copy { ringLattice }
          Origin { 16 * h + 16 * l }
          Rotate { 0.5 * k }
        }
      }
      var ringCarbons = ringSolid._centers.map {
        MRAtom(origin: $0 * 0.357, element: 6)
      }
      
      print("")
      print("ring")
      print("carbon atoms:", ringCarbons.count)
      do {
        var delta = systemCenter - SIMD3<Float>(32, 6, 32) / 2 * 0.357
        delta.y += 7.5 * 0.357
        ringCarbons = ringCarbons.map {
          var copy = $0
          copy.origin += delta
          return copy
        }
      }
      provider = ArrayAtomProvider(providerAtoms + ringCarbons)
#endif
      
      #if false
      let isRotationMode: Bool = true
      
      var ringDiamondoid = Diamondoid(atoms: ringCarbons)
      print("total atoms:", ringDiamondoid.atoms.count)
      ringDiamondoid.minimize()
      if !isRotationMode {
        ringDiamondoid.translate(offset: [0, 1, 0])
      }
      var ringDiamondoidCopy = ringDiamondoid
      do {
        let delta = ringDiamondoidCopy.createCenterOfMass() - systemCenter
        ringDiamondoidCopy.translate(offset: -2 * delta)
        ringDiamondoidCopy.rotate(angle: simd_quatf(
          angle: -180 * .pi / 180, axis: [1, 0, 0]))
//        ringDiamondoidCopy.rotate(angle: simd_quatf(
//          angle: -90 * .pi / 180, axis: [0, 1, 0]))
      }
      
      provider = ArrayAtomProvider(providerAtoms + ringDiamondoid.atoms + ringDiamondoidCopy.atoms)
      
      let diamondoids = dualHousings + springs + [
        ringDiamondoid, ringDiamondoidCopy
      ]
      
      do {
        print()
        print("energy minimization: 8 x 0.5 ps")
        let systemNumAtoms = diamondoids.reduce(0) { $0 + $1.atoms.count }
        print("4 x spring + 4 x housing + 2 x ring =", systemNumAtoms, "atoms")
        
        var start = CACurrentMediaTime()
        let simulator = _Old_MM4(
          diamondoids: diamondoids, fsPerFrame: 20)
        provider = simulator.provider
        
        let speed: Float = 100
        let angularSpeed: Float = 0.08
        let emptyVelocities: [SIMD3<Float>] = Array(
          repeating: .zero, count: systemNumAtoms)
        for i in 0..<8 {
          simulator.simulate(ps: 0.5, minimizing: true)
          if i < 7 {
            simulator.provider.reset()
            simulator.thermalize(velocities: emptyVelocities)
          } else {
            let nonMovingAtoms = diamondoids[0..<8].reduce(0) { $0 + $1.atoms.count }
            let ringAtoms = ringDiamondoid.atoms.count
            var velocities = emptyVelocities
            if isRotationMode {
              let positions = simulator.provider.states.last!.map { $0.origin }
              let w = SIMD3<Float>(0, 1, 0) * angularSpeed
              for j in 0..<nonMovingAtoms + 2 * ringAtoms {
                let r = positions[j] - systemCenter
                velocities[j] = cross(w, r)
              }
            } else {
              for j in nonMovingAtoms..<nonMovingAtoms + ringAtoms {
                velocities[j] = [0, -speed / 1000, 0]
              }
              for j in nonMovingAtoms + ringAtoms..<nonMovingAtoms + 2 * ringAtoms {
                velocities[j] = [0, speed / 1000, 0]
              }
            }
            simulator.provider.reset()
            simulator.thermalize(velocities: velocities)
          }
        }
        var end = CACurrentMediaTime()
        print("simulated in \(String(format: "%.1f", end - start)) seconds")
        
        var numPicoseconds: Double
        print()
        if isRotationMode {
          // The rotation simulation here doesn't go in the animation.
          numPicoseconds = 160
          print("\(angularSpeed) rad/s, \(Int(5 * angularSpeed * 1000)) m/s, \(numPicoseconds) ps")
        } else {
          numPicoseconds = 20
          print("\(speed) m/s, \(numPicoseconds) ps")
        }
        print("4 x spring + 4 x housing + 2 x ring =", systemNumAtoms, "atoms")
        
        start = CACurrentMediaTime()
        simulator.simulate(ps: numPicoseconds)
        end = CACurrentMediaTime()
        print("simulated in \(String(format: "%.1f", end - start)) seconds")
        provider = simulator.provider
      }
      
      #endif
    }
  }
}
