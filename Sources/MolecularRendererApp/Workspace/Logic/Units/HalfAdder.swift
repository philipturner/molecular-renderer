//
//  HalfAdder.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/11/24.
//

import Foundation
import HDL
import MM4
import Numerics

// The logic rods for a half adder.
struct HalfAdderUnit {
  // The A input to the circuit.
  var operandA: Rod
  
  // The B input to the circuit.
  var operandB: Rod
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    [operandA] +
    [operandB]
  }
}
