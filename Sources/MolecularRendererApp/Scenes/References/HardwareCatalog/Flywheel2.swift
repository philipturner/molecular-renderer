//
//  Flywheel2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/27/23.
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

struct Flywheel2_Provider {
  var provider: any MRAtomProvider
  
  init() {
    let ring1 = try! Ring(
      radius: 20, perimeter: 120,
      thickness: 1.0, depth: 1.5,
      innerSpokes: true, outerSpokes: false)
    var ring1Centers = ring1.centers.map { $0 * 0.357 }
    ring1Centers = ring1Centers.filter {
      distance($0, .zero) > 7 * 1.414 * 0.357
    }
    
    let ring2 = try! Ring(
      radius: 5.0, perimeter: 32,
      thickness: 1.0, depth: 1.5,
      innerSpokes: false, outerSpokes: true)
    
    
    let connector1 = makeConnector1()
    let connector3 = makeConnector3()
    let rope1 = try! DiamondRope(height: 1.5, width: 1, length: 5)
    let rope2 = try! DiamondRope(height: 1.5, width: 1, length: 5)
    let connector4 = makeConnector4()
    _ = makeConnector5()
    
    let ring12Solid = Solid { h, k, l in
      Copy { ring1.centers.filter {
        distance($0, .zero) > 7 * 1.414
      } }
      Copy { ring2.centers }
      for i in 0..<4 {
        Affine {
          Copy { connector1 }
          Reflect { +k }
          Translate { -0.125 * k }
          Translate { 5 * k }
          
          if i % 2 == 0 {
            Translate { 0.25 * (-h + k - l) }
          }
          Translate { 4 * h + 4 * l - 4 * k }
          if i > 0 {
            Rotate { Float(i) / 4 * k }
          }
        }
      }
      Affine {
        Copy { connector3 }
        // Warp the beams crossing over the middle, so they point under a
        // little, and avoid the infinitely repulsive vdW interactions with
        // hydrogens on the other part.
        Translate { -10 * (h + l) - 5.125 * k }
      }
      for rotationID in 0..<2 {
        Affine {
          Copy { rope1.lattice }
          Translate { -7.25 * (h + l) - 4.625 * k }
          Translate { 0.25 * (h - l) }
          if rotationID == 1 { Rotate { 0.5 * k } }
        }
        Affine {
          Copy { rope2.lattice }
          Rotate { 0.25 * k }
          Translate { -7.5 * (h - l) - 4.875 * k }
          Translate { 0.25 * (-h - l) }
          if rotationID == 1 { Rotate { 0.5 * k } }
        }
      }
      Affine {
        Copy { connector4 }
        Translate { -4 * (h + l) - 5.125 * k }
      }
    }
    let ring12Centers = deduplicate(ring12Solid._centers)
      .map { $0 * 0.357 }
    provider = ArrayAtomProvider(ring12Centers)
    print("ring12 (C):", ring12Centers.count)
    
    
    
    
    let connector2 = makeConnector2()
    
    let ring3 = try! Ring(
      radius: 4, perimeter: 24,
      thickness: 1.0, depth: 1.5,
      innerSpokes: true, outerSpokes: false)
    let ring3Centers = ring3.centers
      .filter { distance($0 * [1, 0, 1], .zero) > 3.0 * 1.414 }
    provider = ArrayAtomProvider(connector2._centers.map { $0 * 0.357 })
    
    let ring34 = Solid { h, k, l in
      Copy { ring3Centers }
      Affine {
        Copy { ring3Centers }
        Translate { 3 * k }
      }
      for i in 0..<4 {
        Affine {
          Copy { connector2 }
          Translate { -0.125 * k }
          if i % 2 == 1 {
            Translate { 0.125 * k }
            Reflect { +k }
            Translate { -0.125 * k }
            Translate { 4 * k }
          }
          if i > 0 {
            Rotate { Float(i) / 4 * k }
          }
        }
      }
    }
    
    let ring34Centers = deduplicate(ring34._centers).map { $0 * 0.357 }
    provider = ArrayAtomProvider(ring34Centers)
    print("ring34 (C):", ring34Centers.count)
    
    provider = ArrayAtomProvider(ring12Centers + ring34Centers.map {
      $0 + SIMD3(0, -1.5 * Float(0.357), 0)
    })
//    return
    
    
    
    var ring12Diamondoid = Diamondoid(
      carbonCenters: ring12Centers, ccBondRange: 0.12...0.18)
    ring12Diamondoid.translate(offset: [0, 1.5 * Float(0.357), 0])
    print("ring12 (C + H):", ring12Diamondoid.atoms.count)
//    ring12Diamondoid.minimize()
    provider = ArrayAtomProvider(ring12Diamondoid.atoms)
//    return
    
    var ring12CenterOfMass = ring12Diamondoid.createCenterOfMass()
    // NOTE: Will always need to fine-tune this after adding more mass.
    ring12CenterOfMass.y += 0.35
    let ring12Radius = ring12Diamondoid.atoms.filter {
      $0.element == 6
    }.map { $0.origin }.reduce(0) {
      max($0, distance($1 * [1, 0, 1], ring12CenterOfMass))
    }
    print(ring12Radius)
    
    var ring34Diamondoid = Diamondoid(
      carbonCenters: ring34Centers, ccBondRange: 0.14...0.18)
    print("ring34 (C + H):", ring34Diamondoid.atoms.count)
    ring34Diamondoid.translate(
      offset: ring12CenterOfMass - ring34Diamondoid.createCenterOfMass())
//    ring34Diamondoid.minimize()
    provider = ArrayAtomProvider(ring34Diamondoid.atoms)
    provider = ArrayAtomProvider(ring12Diamondoid.atoms + ring34Diamondoid.atoms)
//    return
    

    let simulator = _Old_MM4(
      diamondoids: [ring12Diamondoid, ring34Diamondoid], fsPerFrame: 20)
    
    for i in 0..<8 {
      simulator.simulate(ps: 0.5, minimizing: true)
      var velocities: [SIMD3<Float>] = .init(
        repeating: .zero,
        count: ring12Diamondoid.atoms.count + ring34Diamondoid.atoms.count)
      let positions = simulator.provider.states.last!.map { $0.origin }

      let centerOfMass = ring12Diamondoid.createCenterOfMass()
      let w = SIMD3<Float>(0, 2100.0 / 1000 / ring12Radius, 0)
      for i in ring12Diamondoid.atoms.indices {
        let atomID = i
        let r = positions[atomID] - centerOfMass
        velocities[atomID] = cross(w, r)
      }
      if i == 7 {
        for i in ring34Diamondoid.atoms.indices {
          let atomID = i + ring12Diamondoid.atoms.count
          velocities[atomID] = SIMD3(0, 0, 0)
        }
      }
      
      simulator.provider.reset()
      simulator.thermalize(velocities: velocities)
    }
    simulator.simulate(ps: 10)
    provider = simulator.provider
  }
}

fileprivate func makeConnector1() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    let height: Float = 4.75
    Material { .carbon }
    Bounds { 5 * h + ceil(height) * k + 5 * l }
    
    Volume {
      Convex {
        Origin { height * k }
        Plane { +k }
      }
      Origin { 2.5 * h + 2.5 * l }
      
      for hDirection in [Float(1), -1] { Concave {
        Convex {
          Origin { 0.75 * hDirection * h }
          Ridge(hDirection * h + l) { hDirection * h }
        }
      } }
      for kDirection in [Float(1), -1] { Convex {
        if kDirection == 1 {
          Origin { height * k }
        }
        Ridge(kDirection * k + h + kDirection * l) { kDirection * k }
        Origin { 0.25 * kDirection * k }
        Ridge(kDirection * k + h - kDirection * l) { kDirection * k }
      } }
      Cut()
    }
  }
}


fileprivate func makeConnector2() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    let height: Float = 4.75
    Material { .carbon }
    Bounds { 5 * h + ceil(height) * k + 5 * l }
    
    Volume {
      Convex {
        Origin { height * k }
        Plane { +k }
      }
      Convex {
        Origin { 0.5 * h + 0.5 * l }
        Plane { -h - l + k }
      }
      Origin { 2.5 * h + 2.5 * l }
      for hDirection in [Float(1), -1] { Concave {
        Convex {
          Origin { 0.75 * hDirection * h }
          Ridge(hDirection * h + l) { hDirection * h }
        }
        if hDirection == 1 {
          Convex {
            Origin { 2 * (h + k + l) + 3.25 * k }
            Convex {
              Origin { -2 * k }
              Plane { +k }
              Origin { -1.5 * k }
              Plane { -k }
            }
            Convex {
              Plane { h - k + l }
              Origin { 0.25 * (h - l) }
              Plane { h - l }
            }
          }
        }
      } }
      for kDirection in [Float(1), -1] { Convex {
        if kDirection == 1 {
          Origin { height * k }
        }
        Ridge(kDirection * k + h + kDirection * l) { kDirection * k }
        Origin { 0.25 * kDirection * k }
        Ridge(kDirection * k + h - kDirection * l) { kDirection * k }
      } }
      Cut()
    }
  }
}

fileprivate func makeConnector3() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    Material { .carbon }
    Bounds { 20 * h + 4 * k + 20 * l }
    
    Volume {
      Origin { 10 * h + 10 * l }
      
      Concave {
        Concave {
          for hlDirection in [Float(1), -1] {
            Convex {
              Origin { 4.75 * hlDirection * (h + l) }
              Plane { hlDirection * (-h - l) + k }
              Origin { 3 * k }
              Plane { hlDirection * (-h - l) - k }
            }
            Convex {
              Origin { 5.25 * hlDirection * (h - l) }
              Plane { hlDirection * (-h + l) + k }
              Origin { 2 * k }
              Plane { hlDirection * (-h + l) - k }
            }
          }
        }
        for hlDirection in [Float(1), -1] {
          Concave {
            Origin { 6 * hlDirection * (h + l) + 0.75 * k }
            Convex {
              Plane { hlDirection * -h + k }
              Origin { 1 * k }
              Plane { hlDirection * -h - k }
            }
            Convex {
              Plane { hlDirection * -l + k }
              Origin { 1 * k }
              Plane { hlDirection * -l - k }
            }
          }
        }
      }
      for hlDirection in [Float(1), -1] {
        Convex {
          Origin { 9 * hlDirection * (h + l) + 0.75 * k }
          Plane { hlDirection * h + k }
          Plane { hlDirection * l + k }
          Origin { 1 * k }
          Plane { hlDirection * h - k }
          Plane { hlDirection * l - k }
        }
        Convex {
          Origin { 7.75 * hlDirection * (h + l) + 0.75 * k }
          Plane { hlDirection * (h + l) + k }
          Origin { -0.25 * hlDirection * (h + l) }
          Origin { 2 * k }
          Plane { hlDirection * (h + l) - k }
        }
        Convex {
          Origin { 7.75 * hlDirection * (h - l) + 0.75 * k }
          Plane { hlDirection * (h - l) + k }
          Origin { -0.25 * hlDirection * (h - l) }
          Origin { 1 * k }
          Plane { hlDirection * (h - l) - k }
        }
      }
      
      Cut()
    }
  }
}

fileprivate func makeConnector4() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    Material { .carbon }
    Bounds { 8 * h + 5 * k + 8 * l }
    
    Volume {
      Origin { 4 * h + 4 * l }
      Convex {
        Convex {
          Origin { 4.5 * k }
          Ridge(h + k + l) { +k }
        }
        Convex {
          Origin { 4.75 * k }
          Ridge(h + k - l) { +k }
        }
      }
      Concave {
        Convex {
          Origin { 2.5 * k }
          Valley(h - k + l) { -k }
        }
        Convex {
          Origin { 3.0 * k }
          Valley(h - k - l) { -k }
        }
      }
      Convex {
        Convex {
          Origin { -2.75 * k }
          Ridge(h - k + l) { -k }
        }
        Convex {
          Origin { -3.25 * k }
          Ridge(h - k - l) { -k }
        }
      }
      Concave {
        Convex {
          Origin { 1.5 * k }
          Valley(h + k + l) { +k }
        }
        Convex {
          Origin { 1.5 * k }
          Valley(h + k - l) { +k }
        }
      }
      Cut()
    }
  }
}

fileprivate func makeConnector5() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    Material { .carbon }
    Bounds { 10 * h + 10 * k + 10 * l }
    
    Volume {
      Convex {
        Origin { 0.25 * (h + k + l) }
        Plane { -1 * (h + k + l) }
      }
      Convex {
        Origin { 0.25 * (h - k + l) }
        Plane { h - k + l }
      }
      Convex {
        Origin { 6.5 * k }
        Plane { -h + k - l }
      }
      Convex {
        Origin { 4 * (h + k + l) }
        Plane { h + k + l }
      }
      Convex {
        Origin { 4 * (h + k + l) }
        Origin { 2 * (-h + k - l) }
        Origin { 2.25 * k }
        Ridge(h + k - l) { +k }
      }
      for direction in [h - l, -h + l] {
        Convex {
          Origin { 0.5 * direction }
          Plane { direction }
        }
        Concave {
          Origin { 0.25 * direction }
          Plane { direction }
          Origin { 2.5 * k }
          Plane { +k }
        }
      }
      Cut()
    }
  }
}
