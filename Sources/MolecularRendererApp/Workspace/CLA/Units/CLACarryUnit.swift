//
//  CLACarryUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLACarryUnit {
  // The carry in.
  var carryIn: Rod
  
  // The carry signal.
  //
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // The value of A XOR B.
  //
  // Ordered from bit 0 -> bit 3.
  var xor: [Rod] = []
  
  var rods: [Rod] {
    [carryIn] + signal +
    xor
  }
  
  init() {
    var horizontalRodLength: Float = .zero
    horizontalRodLength += 3 * 6
    horizontalRodLength += (6 * 6) + 4
    
    // Make the carry rod five atomic layers thick; the pattern will reduce it
    // to four layers.
    let carryRodLattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      
      var dimensionH = Float(horizontalRodLength)
      dimensionH *= Constant(.square) { .elemental(.carbon) }
      dimensionH /= Constant(.hexagon) { .elemental(.carbon) }
      dimensionH.round(.up)
      Bounds { dimensionH * h + 3 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 2.51 * h2k }
        Plane { h2k }
        Replace { .empty }
      }
    }
    
    // Nested function for shifting into the local coordinate space.
    func shift(rod: inout Rod) {
      rod.translate(x: 3 * 6)
      rod.translate(x: 3 * 8 + 8)
      rod.translate(z: -3 * 6)
    }
    
    var carryRod = Rod(lattice: carryRodLattice)
    carryRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    carryRod.translate(y: -0.1)
    
    // Create the carry in.
    do {
      var rod = carryRod
      shift(rod: &rod)
      rod.translate(y: 5.5)
      carryIn = rod
    }
    
    // Create the signal.
    for layerID in 1...4 {
      var rod = carryRod
      shift(rod: &rod)
      rod.translate(y: Float(layerID) * 6)
      rod.translate(y: 5.5)
      signal.append(rod)
    }
    
    // Create the xor.
    let xorRodLattice = Rod.createLattice(
      length: horizontalRodLength)
    var xorRod = Rod(lattice: xorRodLattice)
    xorRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    
    for layerID in 1...4 {
      var rod = xorRod
      shift(rod: &rod)
      rod.translate(x: 6)
      rod.translate(y: Float(layerID) * 6)
      xor.append(rod)
    }
  }
}
