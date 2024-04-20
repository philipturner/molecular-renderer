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
    let signalRodLattice = Self.createLattice(
      length: (3 * 6) + (3 * 8 + 4) + 2)
    let signalRod = Rod(lattice: signalRodLattice)
    
    for layerID in 1...4 {
      var rod = signalRod
      rod.translate(y: Double(layerID) * 6)
      rod.translate(y: 2.75)
      rod.translate(z: 5 * 6)
      rod.translate(z: 2.75)
      signal.append(rod)
    }
    
    // Create the vertical probes.
    let probeRodLattice = Self.createLattice(
      length: (5 * 6) + 4)
    var probeRod = Rod(lattice: probeRodLattice)
    probeRod.rotate(angle: .pi / 2, axis: [0, 0, 1])
    probeRod.rotate(angle: .pi / 2, axis: [0, 1, 0])
    
    for positionX in 0..<3 {
      var rod = probeRod
      rod.translate(x: 2 * 6)
      rod.translate(x: Double(positionX) * 8)
      rod.translate(x: 3.5)
      rod.translate(z: 5 * 6)
      
      let key = positionX
      probe[key] = rod
    }
    
    // Create the broadcast lines.
    let broadcastRodLattice = Self.createLattice(
      length: (6 * 6) + 4)
    var broadcastRod = Rod(lattice: broadcastRodLattice)
    broadcastRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    
    for layerID in 1...4 {
      for positionX in 0..<layerID {
        var rod = broadcastRod
        rod.translate(x: 3 * 6)
        if positionX == 3 {
          rod.translate(x: 3 * 8 - 2)
        } else {
          rod.translate(x: Double(positionX) * 8)
        }
        rod.translate(y: Double(layerID) * 6)
        
        let key = SIMD2(Int(positionX), Int(layerID))
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
