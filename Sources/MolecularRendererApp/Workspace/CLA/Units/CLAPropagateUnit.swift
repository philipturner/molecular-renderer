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
    var horizontalRodLength: Float = .zero
    horizontalRodLength += 3 * 6
    horizontalRodLength += 3 * 8 + 4
    horizontalRodLength += (2 * 6) + 2
    
    // Create the signal.
    let signalRodLattice = Rod.createLattice(
      length: horizontalRodLength)
    let signalRod = Rod(lattice: signalRodLattice)
    
    for layerID in 1...4 {
      var rod = signalRod
      rod.translate(y: Float(layerID) * 6)
      rod.translate(y: 2.75)
      rod.translate(z: 5 * 6)
      rod.translate(z: 2.75)
      signal.append(rod)
    }
    
    // Create the vertical probes.
    let probeRodLattice = Rod.createLattice(
      length: (5 * 6) + 2)
    var probeRod = Rod(lattice: probeRodLattice)
    probeRod.rotate(angle: .pi / 2, axis: [0, 0, 1])
    probeRod.rotate(angle: .pi / 2, axis: [0, 1, 0])
    
    for positionX in 0..<3 {
      var rod = probeRod
      rod.translate(x: 2 * 6)
      rod.translate(x: Float(positionX) * 8)
      rod.translate(x: 3.5)
      rod.translate(y: 2)
      rod.translate(z: 5 * 6)
      
      let key = positionX
      probe[key] = rod
    }
    
    // Create the broadcast lines.
    let broadcastRodLattice = Rod.createLattice(
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
          rod.translate(x: Float(positionX) * 8)
        }
        rod.translate(y: Float(layerID) * 6)
        
        let key = SIMD2(Int(positionX), Int(layerID))
        broadcast[key] = rod
      }
    }
  }
}
