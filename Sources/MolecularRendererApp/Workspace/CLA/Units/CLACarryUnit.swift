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
    let horizontalRodLength: Int = (3 * 6) + (6 * 6) + 4
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
    var carryRod = Rod(lattice: carryRodLattice)
    carryRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    carryRod.translate(y: -0.1)
    
    // Create the carry in.
    do {
      var rod = carryRod
      rod.translate(x: 3 * 6)
      rod.translate(x: 3 * 8 + 4)
      rod.translate(y: 5.5)
      rod.translate(z: -3 * 6)
      carryIn = rod
    }
    
    // Create the signal.
    for layerID in 1...4 {
      var rod = carryRod
      rod.translate(x: 3 * 6)
      rod.translate(x: 3 * 8 + 4)
      rod.translate(y: Double(layerID) * 6)
      rod.translate(y: 5.5)
      rod.translate(z: -3 * 6)
      signal.append(rod)
    }
    
    // Create the xor.
    let xorRodLattice = Rod.createLattice(
      length: horizontalRodLength)
    var xorRod = Rod(lattice: xorRodLattice)
    xorRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    
    for layerID in 1...4 {
      var rod = xorRod
      rod.translate(x: 3 * 6)
      rod.translate(x: 3 * 8 + 4)
      rod.translate(x: 6)
      rod.translate(y: Double(layerID) * 6)
      rod.translate(z: -3 * 6)
      xor.append(rod)
    }
  }
}
