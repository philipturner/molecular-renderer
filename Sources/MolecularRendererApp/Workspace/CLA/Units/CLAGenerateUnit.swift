//
//  CLAGenerateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAGenerateUnit {
  // The carry in.
  var carryIn: Rod
  
  // The generate signal.
  //
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // The generate signal, transmitted vertically.
  // - keys: The source layer (>= 0), or 'carryIn' (-1).
  // - values: The associated logic rods.
  var probe: [Int: Rod] = [:]
  
  // The carry chains that terminate at the current bit.
  // - keys: The source layer (lane 0) and the destination layer (lane 1).
  // - values: The associated logic rods.
  var broadcast: [SIMD2<Int>: Rod] = [:]
  
  var rods: [Rod] {
    [carryIn] + signal +
    Array(probe.values) +
    Array(broadcast.values)
  }
  
  init() {
    let signalRodLattice = Self.createLattice(
      length: 6 * 3 + (6 + 2 + 6 + 2 + 6 + 6) + 2)
    let signalRod = Rod(lattice: signalRodLattice)
    
    // Create the carry in.
    do {
      var rod = signalRod
      rod.rigidBody.centerOfMass.y += 2.75 * 0.3567
      rod.rigidBody.centerOfMass.z += 4 * 6 * 0.3567
      carryIn = rod
    }
    
    // Create the signal.
    for layerID in 1...4 {
      var rod = signalRod
      rod.rigidBody.centerOfMass.y += Double(layerID) * 6 * 0.3567
      rod.rigidBody.centerOfMass.y += 2.5 * 0.3567
      rod.rigidBody.centerOfMass.z += Double(4 - layerID) * 6 * 0.3567
      signal.append(rod)
    }
    
    // Create the vertical probes.
    let probeRodLattice = Self.createLattice(length: 6 * 5 + 2)
    var probeRod = Rod(lattice: probeRodLattice)
    probeRod.rigidBody.rotate(angle: .pi / 2, axis: [0, 0, 1])
    probeRod.rigidBody.centerOfMass = SIMD3(
      probeRod.rigidBody.centerOfMass.y,
      probeRod.rigidBody.centerOfMass.x,
      probeRod.rigidBody.centerOfMass.z)
    
    for positionZ in 0...3 {
      var rod = probeRod
      rod.rigidBody.centerOfMass.x += 2 * 6 * 0.3567
      rod.rigidBody.centerOfMass.z += Double(positionZ) * 6 * 0.3567
      rod.rigidBody.centerOfMass.z += 3.5 * 0.3567
      
      let key = 2 - positionZ
      probe[key] = rod
    }
    
    // Create the broadcast lines.
    let broadcastRodLattice = Self.createLattice(length: 6 * 5 + 2)
    let broadcastRod = Rod(lattice: broadcastRodLattice)
    
    for layerID in 1...4 {
      for positionZ in ((4 - layerID) + 1)...4 {
        var rod = broadcastRod
        rod.rigidBody.centerOfMass.y += Double(layerID) * 6 * 0.3567
        rod.rigidBody.centerOfMass.y += 2.5 * 0.3567
        rod.rigidBody.centerOfMass.z += Double(positionZ) * 6 * 0.3567
        
        let key = SIMD2(Int(positionZ), Int(layerID))
        broadcast[key] = rod
      }
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
    }
  }
}