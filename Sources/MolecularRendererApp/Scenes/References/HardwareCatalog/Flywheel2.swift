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
      radius: 20, perimeter: 124,
      thickness: 1.0, depth: 1.5,
      innerSpokes: true, outerSpokes: false)
    var ring1Centers = ring1.centers.map { $0 * 0.357 }
    ring1Centers = ring1Centers.filter {
      distance($0, .zero) > 7 * 1.414 * 0.357
    }
    
    let ring2 = try! Ring(
      radius: 5, perimeter: 32,
      thickness: 1.0, depth: 1.5,
      innerSpokes: false, outerSpokes: true)
    let ring2Centers = ring2.centers.map { $0 * 0.357 }
    
    let ring12Centers = deduplicate(ring1Centers + ring2Centers)
    provider = ArrayAtomProvider(ring12Centers)
    print("ring12 (C):", ring12Centers.count)
    
    let ring3 = try! Ring(
      radius: 4, perimeter: 24,
      thickness: 1.0, depth: 1.5,
      innerSpokes: true, outerSpokes: false)
    let ring3Centers = ring3.centers
      .filter { distance($0 * [1, 0, 1], .zero) > 2 * 1.414 }
    
    let connector = Lattice<Cubic> { h, k, l in
      let height: Float = 4.75
      Material { .carbon }
      Bounds { 3 * h + ceil(height) * k + 3 * l }
      
      Volume {
        Convex {
          Origin { height * k }
          Plane { +k }
        }
        Origin { 1.5 * h + 1.5 * l }
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
    provider = ArrayAtomProvider(connector._centers.map { $0 * 0.357 })
    
    let ring34 = Solid { h, k, l in
      Copy { ring3Centers }
      Affine {
        Copy { ring3Centers }
        Translate { 3 * k }
      }
      for i in 0..<4 {
        Affine {
          Copy { connector }
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
    
    
    var ring12Diamondoid = Diamondoid(
      carbonCenters: ring12Centers, ccBondRange: 0.14...0.18)
    ring12Diamondoid.translate(offset: [0, 1.5 * Float(0.357), 0])
    print("ring12 (C + H):", ring12Diamondoid.atoms.count)
//    ring12Diamondoid.minimize()
    provider = ArrayAtomProvider(ring12Diamondoid.atoms)
//    
    var ring34Diamondoid = Diamondoid(
      carbonCenters: ring34Centers, ccBondRange: 0.14...0.18)
    print("ring34 (C + H):", ring34Diamondoid.atoms.count)
//    ring34Diamondoid.minimize()
    provider = ArrayAtomProvider(ring34Diamondoid.atoms)
    
    provider = ArrayAtomProvider(ring12Diamondoid.atoms + ring34Diamondoid.atoms)
    
    
  }
}
