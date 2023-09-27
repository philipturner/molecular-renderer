//
//  DiamondRope.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/25/23.
//

import Foundation
import MolecularRenderer
import HardwareCatalog
import HDL
import simd
import QuartzCore

struct DiamondRope_Provider {
  var provider: any MRAtomProvider
  
  init() {
    let jigLattice1 = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds { 10 * h + 10 * k + 10 * l }
      
      Volume {
        Origin { 5 * h + 4.5 * k + 5 * l }
        
        Concave {
          Convex {
            Concave {
              for heightDirection in [Float(1), Float(-1)] {
                Concave {
                  Origin { heightDirection * -3 * k }
                  Valley(h + heightDirection * k - l) { heightDirection * k }
                }
              }
            }
            for heightDirection in [Float(1), Float(-1)] {
              Concave {
                Origin { heightDirection * 2 * k }
                Valley(h + heightDirection * k - l) { heightDirection * k }
              }
            }
            for lengthDirection in [Float(1), Float(-1)] {
              Concave {
                Origin { lengthDirection * 1 * (h + l) }
                Plane { lengthDirection * (h + l) }
              }
            }
          }
          Concave {
            for heightDirection in [Float(1), Float(-1)] {
              Convex {
                Origin { heightDirection * 3 * k }
                Origin { h + l }
                for heightDirection2 in [Float(1), Float(-1)] {
                  Convex {
                    Origin { heightDirection2 * k }
                    if heightDirection == -1, heightDirection2 == 1 {
                      Origin { 0.5 * k }
                    }
                    Ridge(h + heightDirection2 * k + l) { heightDirection2 * k }
                  }
                }
              }
            }
          }
        }
        for heightDirection in [Float(1), Float(-1)] {
          Convex {
            Origin { heightDirection * 6 * k }
            Ridge(h + heightDirection * k - l) { heightDirection * k }
          }
        }
        
        Cut()
      }
    }
    let jigLattice2 = try! DiamondRope(height: 1.5, width: 1, length: 6).lattice
    
    let jigSolid1 = Solid { h, k, l in
      Copy { jigLattice1 }
      Affine {
        Copy { jigLattice2 }
        Translate { 5 * (h + l) + 1 * k }
      }
    }
    let jigSolid2 = Solid { h, k, l in
      Copy { jigSolid1 }
      Affine {
        Copy { jigSolid1 }
        Reflect { h + l }
        Reflect { k }
        Translate { 18 * (h + l) }
        Translate { 9 * k }
        
        Translate { 0.25 * (h - l) }
        Translate { -0.25 * k }
      }
    }
    let jigAtoms = jigSolid2._centers.map {
      MRAtom(origin: ($0 + [0, -4, 0]) * 0.357, element: 6)
    }
    
    let tetrahedron = Lattice<Cubic> { h, k, l in
      Material { .carbon }
      Bounds { 4 * h + 4 * k + 4 * l }
      
      Volume {
        Origin { 0.5 * k }
        Ridge(h - k + l) { -k }
        Origin { 3 * k }
        Ridge(h + k - l) { +k }
        Cut()
      }
    }
    let rope = try! DiamondRope(height: 1.5, width: 1, length: 40)
    let weightLattice = RhombicDodecahedron(width: 10).lattice
    let ropeSolid1 = Solid { h, k, l in
      Copy { rope.lattice }
      Affine {
        Copy { tetrahedron }
        Translate { 0 * (h + l) - 2 * k }
      }
      Affine {
        Copy { weightLattice }
        Translate { -7 * (h + l) }
        Translate { -7 * k }
      }
    }
    let ropeSolid2 = Solid { h, k, l in
      Copy { ropeSolid1 }
      Affine {
        Copy { ropeSolid1 }
        Reflect { h + l }
        Reflect { k }
        Translate { 40.25 * (h + l) }
        Translate { 1.25 * k }
      }
    }
    let ropeAtoms = ropeSolid2._centers.map {
      MRAtom(origin: $0 * 0.357, element: 6)
    }
    
    func deduplicate(_ atoms: [MRAtom]) -> [MRAtom] {
      var newAtoms: [MRAtom] = []
      for i in 0..<atoms.count {
        let atom = atoms[i]
        if newAtoms.contains(where: {
          let delta = $0.origin - atom.origin
          return sqrt((delta * delta).sum()) < 0.001
        }) {
          continue
        } else {
          newAtoms.append(atom)
        }
      }
      return newAtoms
    }
    
    var ropeDiamondoid = Diamondoid(atoms: deduplicate(ropeAtoms))
    var jigDiamondoid = Diamondoid(atoms: deduplicate(jigAtoms))
    ropeDiamondoid.translate(
      offset: jigDiamondoid.createCenterOfMass()
      - ropeDiamondoid.createCenterOfMass())
    jigDiamondoid.rotate(angle: simd_quatf(
      angle: 0.08, axis: normalize(SIMD3<Float>([-1, 0, 1]))))
    jigDiamondoid.rotate(angle: simd_quatf(angle: -0.02, axis: [0, 1, 0]))
    provider = ArrayAtomProvider(ropeDiamondoid.atoms + jigDiamondoid.atoms)
    
    #if false
    let simulator = _Old_MM4(
      diamondoids: [ropeDiamondoid, jigDiamondoid], fsPerFrame: 20)
    let numAtoms = ropeDiamondoid.atoms.count + jigDiamondoid.atoms.count
    print("\(numAtoms) atoms")
    
    print("energy minimization: 8 x 0.5 ps")
    let emptyVelocities = [SIMD3<Float>](repeating: .zero, count: numAtoms)
    for i in 0..<8 {
      simulator.simulate(ps: 0.5, minimizing: true)
      if i == 7 {
        provider = ArrayAtomProvider(simulator.provider.states.last!)
      }
      simulator.provider.reset()
      simulator.thermalize(velocities: emptyVelocities)
    }
    
    let numPicoseconds1: Double = 5
    print("simulation: \(numPicoseconds1) ps")
    simulator.simulate(ps: numPicoseconds1)
    let oldStates = simulator.provider.states
    simulator.provider.reset()
    
    var radius: Float
    do {
      let jigCenters = jigDiamondoid.atoms.map { $0.origin }
      let componentsXZ = jigCenters.map { dot($0, normalize([1, 0, 1])) }
      print("span xz:", componentsXZ.min()!, componentsXZ.max()!, componentsXZ.max()! - componentsXZ.min()!)
      
      let center = jigDiamondoid.createCenterOfMass()
      let componentsR = jigCenters.map { length($0 - center) }
      radius = componentsR.max()!
      print("radius: ", radius)
    }
    
    let numPicoseconds2: Double = 40
    do {
      let angularSpeedInRadPs: Float = 0.240
      let ropeVelocities = [SIMD3<Float>](
        repeating: .zero, count: ropeDiamondoid.atoms.count)
      let angularVelocity1 = simd_quatf(
        angle: angularSpeedInRadPs * 1, axis: normalize(SIMD3<Float>([-1, 0, 1])))
      let angularVelocity2 = simd_quatf(
        angle: angularSpeedInRadPs * 0.1, axis: normalize(SIMD3<Float>([1, 0, 0])))
      
      jigDiamondoid.angularVelocity = angularVelocity1
      let jigVelocities1 = jigDiamondoid.createVelocities()
      jigDiamondoid.angularVelocity = angularVelocity2
      let jigVelocities2 = jigDiamondoid.createVelocities()
      let jigVelocities = (0..<jigVelocities1.count).map {
        jigVelocities1[$0] + jigVelocities2[$0]
      }
      simulator.thermalize(velocities: ropeVelocities + jigVelocities)
      
      let angle = angularVelocity1.angle //+ angularVelocity2.angle
      let linearSpeedInNmPs = radius * angle
      print("\(angle) rad/ps (\(Int(linearSpeedInNmPs * 1000)) m/s), \(Int(numPicoseconds2)) ps")
    }
    
    simulator.simulate(ps: numPicoseconds2)
    simulator.provider.states = oldStates + simulator.provider.states
    
    #if false
    for frameID in simulator.provider.states.indices {
      // TODO: Take a histogram of the bond length distributions, graph it
      // at several different points in time. Or color any atoms with bond
      // lengths exceeding a certain value as red (oxygen).
      var frame = simulator.provider.states[frameID]
      for bond in ropeDiamondoid.bonds {
        var atom1 = frame[Int(bond[0])]
        var atom2 = frame[Int(bond[1])]
        guard atom1.element >= 6 && atom2.element >= 6 else {
          continue
        }
        let distance = length(atom1.origin - atom2.origin)
        var newAtomicNumber: UInt8 = 6
        if distance > 0.160 {
          newAtomicNumber = 7
        }
        if distance > 0.169 {
          newAtomicNumber = 8
        }
        if distance > 0.178 {
          newAtomicNumber = 9
        }
        if distance > 0.187 {
          newAtomicNumber = 10
        }
        atom1.element = max(atom1.element, newAtomicNumber)
        atom2.element = max(atom2.element, newAtomicNumber)
        frame[Int(bond[0])] = atom1
        frame[Int(bond[1])] = atom2
      }
      simulator.provider.states[frameID] = frame
    }
    #endif
    
    provider = simulator.provider
    
    #endif
  }
}
