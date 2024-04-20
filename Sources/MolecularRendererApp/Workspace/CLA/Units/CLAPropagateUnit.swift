//
//  CLAPropagateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAPropagateUnit {
  // The propagate signal.
  //
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // The propagate signal, transmitted vertically.
  // - keys: The source layer.
  // - values: The associated logic rods.
  var probe: [Int: Rod] = [:]
  
  // The propagate signal, broadcasted to every applicable carry chain.
  // - keys: The source x-index (0) and the destination layer (1).
  // - values: The associated logic rods.
  var broadcast: [SIMD2<Int>: Rod] = [:]
  
  var rods: [Rod] {
    signal +
    Array(probe.values) +
    Array(broadcast.values)
  }
  
  init() {
    // Create the signal.
    let signalRodLattice = Self.createLattice(length: 6 * 5 + 2)
    let signalRod = Rod(lattice: signalRodLattice)
    
    for layerID in 1...4 {
      var rod = signalRod
      rod.rigidBody.centerOfMass.y += Double(layerID) * 6 * 0.3567
      rod.rigidBody.centerOfMass.y += 2.75 * 0.3567
      rod.rigidBody.centerOfMass.z += (5 * 6 + 2) * 0.3567
      signal.append(rod)
    }
    
    // Create the vertical probes.
    let probeRodLattice = Self.createLattice(length: 6 * 5 + 2)
    var probeRod = Rod(lattice: probeRodLattice)
    probeRod.rigidBody.rotate(angle: .pi / 2, axis: [1, 0, 0])
    probeRod.rigidBody.centerOfMass = SIMD3(
      probeRod.rigidBody.centerOfMass.x,
      probeRod.rigidBody.centerOfMass.z,
      probeRod.rigidBody.centerOfMass.y)
    probeRod.rigidBody.rotate(angle: .pi / 2, axis: [0, 0, 1])
    probeRod.rigidBody.centerOfMass = SIMD3(
      probeRod.rigidBody.centerOfMass.z,
      probeRod.rigidBody.centerOfMass.x,
      probeRod.rigidBody.centerOfMass.y)
    
    for positionX in 0..<3 {
      var rod = probeRod
      rod.rigidBody.centerOfMass.x += (2 * 6 + 2) * 0.3567
      rod.rigidBody.centerOfMass.x += Double(positionX) * 8 * 0.3567
      rod.rigidBody.centerOfMass.z += (4 * 6 + 2) * 0.3567
      rod.rigidBody.centerOfMass.z += 3.5 * 0.3567
      
      let key = positionX
      probe[key] = rod
    }
  }
  
  static func createLattice(length: Int) -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      
      var dimensionH = Float(length)
      dimensionH *= Constant(.square) { .elemental(.carbon) }
      dimensionH /= Constant(.hexagon) { .elemental(.carbon) }
      dimensionH.round(.up)
      Bounds { dimensionH * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 0.49 * l }
        Plane { -l }
        Replace { .empty }
        
        Origin { 0.49 * h2k }
        Plane { -h2k }
        Replace { .empty }
      }
    }
  }
}
