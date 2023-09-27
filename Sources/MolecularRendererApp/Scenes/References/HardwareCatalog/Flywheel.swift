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

struct Flywheel_Provider {
  var provider: any MRAtomProvider
  
  init() {
    let flywheel = Flywheel()
    let centers = flywheel.centers.map { $0 * 0.357 }
    provider = ArrayAtomProvider(centers.map {
      MRAtom(origin: $0, element: 6)
    })
    print(centers.count)
    
    #if true
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
    
    var wheelDiamondoid = Diamondoid(carbonCenters: centers)
    wheelDiamondoid.minimize()
    var wheelDiamondoid2 = wheelDiamondoid
    wheelDiamondoid2.rotate(
      angle: simd_quatf(angle: .pi, axis: normalize([1, 0, -1])))
    wheelDiamondoid2.translate(offset: [0, -1.25, 0])
    
    print(wheelDiamondoid.atoms.count)
    provider = ArrayAtomProvider(
      wheelDiamondoid.atoms + crunchedDiamondoid.atoms)
    #endif
    
    #if true
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
  }
}
