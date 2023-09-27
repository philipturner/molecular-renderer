//
//  Flywheel.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/26/23.
//

import Foundation
import MolecularRenderer
import HardwareCatalog
import HDL
import simd
import QuartzCore

fileprivate func deduplicate(_ atoms: [SIMD3<Float>]) -> [SIMD3<Float>] {
  var newAtoms: [SIMD3<Float>] = []
  for i in 0..<atoms.count {
    let atom = atoms[i]
    if newAtoms.contains(where: {
      let delta = $0 - atom
      return sqrt((delta * delta).sum()) < 0.001
    }) {
      continue
    } else {
      newAtoms.append(atom)
    }
  }
  return newAtoms
}

struct Flywheel_Provider {
  var provider: any MRAtomProvider
  
  init() {
    let flywheel = Flywheel()
    let flywheelCenters = flywheel.centers.map { $0 * 0.357 }
    provider = ArrayAtomProvider(flywheelCenters.map {
      MRAtom(origin: $0, element: 6)
    })
    print("flywheel (C):", flywheelCenters.count)
    
    #if false
    let crunchedRope = try! DiamondRope(height: 1.5, width: 1, length: 10)
    let crunchedCarbons = crunchedRope.lattice._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    var crunchedDiamondoid = Diamondoid(atoms: crunchedCarbons)
    crunchedDiamondoid.minimize()
    crunchedDiamondoid.rotate(
      angle: simd_quatf(angle: .pi / 2, axis: normalize([1, 0, -1])))
    crunchedDiamondoid.translate(
      offset: -crunchedDiamondoid.createCenterOfMass())
    crunchedDiamondoid.translate(offset: [2, 32, 0])
    
    var wheelDiamondoid = Diamondoid(carbonCenters: flywheelCenters)
    wheelDiamondoid.minimize()
    var wheelDiamondoid2 = wheelDiamondoid
    wheelDiamondoid2.rotate(
      angle: simd_quatf(angle: .pi, axis: normalize([1, 0, -1])))
    wheelDiamondoid2.translate(offset: [0, -1.25, 0])
    
    print(wheelDiamondoid.atoms.count)
    provider = ArrayAtomProvider(
      wheelDiamondoid.atoms + crunchedDiamondoid.atoms)
    #endif
    
    #if false
    let simulator = _Old_MM4(diamondoids: [
      wheelDiamondoid, wheelDiamondoid2, crunchedDiamondoid], fsPerFrame: 20)
    var states: [[MRAtom]] = []
    for i in 0...30 {
      simulator.simulate(ps: 0.5)
      states.append(contentsOf: simulator.provider.states)
      simulator.provider.reset()
      let speed: Float = Float(min(i, 21)) * 100
      print("=== speed: \(speed) ===")
      
      // 5 nm radius
      // 1 rad/ps = 5000 m/s
      // 1/5000 rad/ps = 1 m/s
      let meterPerSecond: Float = 1.0 / 5000
      let w = SIMD3<Float>(0, 1, 0) *
        .init(repeating: speed * meterPerSecond)
      let centerOfMass1 = wheelDiamondoid.createCenterOfMass()
      var velocities: [SIMD3<Float>] = []
      for atom in states.last![0..<wheelDiamondoid.atoms.count] {
        let center = atom.origin
        let r = center - centerOfMass1
        velocities.append(cross(w, r))
      }
      
      let count = wheelDiamondoid.atoms.count
      let centerOfMass2 = wheelDiamondoid2.createCenterOfMass()
      for atom in states.last![wheelDiamondoid.atoms.count..<2 * count] {
        let center = atom.origin
        let r = center - centerOfMass2
        velocities.append(-cross(w, r))
      }
      
      if i <= 11 {
        for _ in crunchedDiamondoid.atoms {
          velocities.append(.zero)
        }
      } else {
        for _ in crunchedDiamondoid.atoms {
          velocities.append([0, -0.200 * Float(i - 11), 0])
        }
      }
      simulator.thermalize(velocities: velocities)
    }
    simulator.simulate(ps: 20)
    simulator.provider.states = states + simulator.provider.states
    provider = simulator.provider
    #endif
    
    let octahedralInterfaceLattice = Lattice<Cubic> { h, k, l in
      let width: Float = 8
      Material { .carbon }
      Bounds { width * h + width * k + width * l }
      
      Volume {
        Origin { width / 2 * (h + k + l) }
        
        for hDirection in [Float(1), -1] {
          for kDirection in [Float(1), -1] {
            for lDirection in [Float(1), -1] { Convex {
              let direction = hDirection * h + kDirection * k + lDirection * l
              let vec = SIMD3<Float>(hDirection, kDirection, lDirection) + 1
              Origin { 2.0 * direction }
              
              if Int((vec / 2).sum()) % 2 == 0 {
                Origin { -0.25 * direction }
              }
              if vec == [2, 2, 2] || vec == [0, 0, 0] {
                Origin { -0.5 * direction }
              }
              if vec == [2, 2, 2] {
                Origin { -1 * direction }
              } else {
                Plane { direction }
              }
            } }
          }
        }
        Concave {
          for hDirection in [Float(1), -1] {
            for kDirection in [Float(1), -1] {
              for lDirection in [Float(1), -1] { Convex {
                let direction = hDirection * h + kDirection * k + lDirection * l
                let vec = SIMD3<Float>(hDirection, kDirection, lDirection) + 1
                Origin { 1.5 * direction }
                if Int((vec / 2).sum()) % 2 == 0 {
                  Origin { -0.25 * direction }
                }
                
                if vec == [2, 2, 2] || vec == [0, 0, 0] {
                  Origin { 4 * direction }
                }
                if vec != [2, 2, 2] {
                  Plane { -1.0 * direction }
                }
                
              } }
            }
          }
        }
        for (direction1, direction2, direction3) in [
          (h, k, l), (k, h, l), (l, k, h)
        ] { Concave {
          Convex {
            Origin { 1.25 * direction1 }
            Valley(direction2 - direction3 + direction1) { direction1 }
          }
          Convex {
            Origin { 0.5 * (direction2 + direction3) }
            Plane { h + k + l }
          }
        } }
        Convex {
          Origin { 2 * (h + k + l) }
          Plane { h + k + l }
        }
        Cut()
      }
    }
    let octahedralInterfaceSolid = Solid { h, k, l in
      Affine {
        Copy { octahedralInterfaceLattice }
      }
    }
    let octahedralInterfaceRotation = simd_quatf(
      from: normalize([1, 1, 1]), to: [0, 1, 0])
    var octahedralInterfaceCenters = octahedralInterfaceSolid
      ._centers.map { $0 * 0.357 }
    octahedralInterfaceCenters = octahedralInterfaceCenters.map {
      octahedralInterfaceRotation.act($0)
    }
    print("octahedral interface (C):", octahedralInterfaceCenters.count)
    print("octahedral interface (C + H):", Diamondoid(carbonCenters: octahedralInterfaceCenters).atoms.count)
    
    provider = ArrayAtomProvider(
      octahedralInterfaceCenters + flywheelCenters)
    
    
    // New code to spin up a single flywheel, and do so while energy-
    // minimizing (more efficient). Start at the max velocity while it's
    // already perfectly circular; play back the frames from minimizing.
  }
}
