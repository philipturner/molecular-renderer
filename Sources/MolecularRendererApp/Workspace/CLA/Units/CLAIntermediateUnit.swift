//
//  CLAIntermediateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAIntermediateUnit {
  // The carry signal from each lane.
  //
  // Ordered from bit -1 -> bit 3.
  var carry: [Rod] = []
  
  // The value of A XOR B.
  var xor: [Rod] = []
  
  var rods: [Rod] {
    carry +
    xor
  }
  
  init() {
    // Create the carry.
    let carryRodLattice = Rod.createLattice(
      length: (6 * 6) + 4)
    var carryRod = Rod(lattice: carryRodLattice)
    carryRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    
    for layerID in 0...4 {
      var rod = carryRod
      rod.translate(x: 3 * 6)
      rod.translate(x: 3 * 8 + 4)
      rod.translate(y: Double(layerID) * 6)
      rod.translate(y: 5.5)
      carry.append(rod)
    }
  }
}
