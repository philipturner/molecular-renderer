//
//  CLAOutputUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/20/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLAOutputUnit {
  // The NOR intermediate of the half adder.
  //
  // Ordered from bit 0 -> bit 3.
  var nor: [Rod] = []
  
  // The AND intermediate of the half adder.
  //
  // Ordered from bit 0 -> bit 3.
  var and: [Rod] = []
  
  // The sum output of the circuit.
  var sum: [Rod] = []
  
  var rods: [Rod] {
    nor + and + sum
  }
  
  init() {
    // Nested function for shifting into the local coordinate space.
    func shift(rod: inout Rod) {
      rod.translate(x: 3 * 6)
      rod.translate(x: 3 * 8 + 4)
      rod.translate(z: -3 * 6)
    }
    
    // Create the nor.
    let norRodLattice = Rod.createLattice(
      length: (3 * 6) + 2)
    var norRod = Rod(lattice: norRodLattice)
    shift(rod: &norRod)
    
    for layerID in 1...4 {
      var rod = norRod
      rod.translate(y: Float(layerID) * 6)
      rod.translate(y: 2.75)
      nor.append(rod)
    }
    
    // Create the and.
    let andRodLattice = Rod.createLattice(
      length: (3 * 6) + 2)
    var andRod = Rod(lattice: andRodLattice)
    shift(rod: &andRod)
    
    for layerID in 1...4 {
      var rod = andRod
      rod.translate(y: Float(layerID) * 6)
      rod.translate(y: 2.75)
      rod.translate(z: 6)
      nor.append(rod)
    }
    
    // Create the sum.
    let sumRodLattice = Rod.createLattice(
      length: (2 * 6) + 2)
    var sumRod = Rod(lattice: sumRodLattice)
    sumRod.rotate(angle: -.pi / 2, axis: [0, 1, 0])
    shift(rod: &sumRod)
    
    for layerID in 1...4 {
      var rod = sumRod
      rod.translate(x: 2 * 6)
      rod.translate(y: Float(layerID) * 6)
      sum.append(rod)
    }
  }
}
