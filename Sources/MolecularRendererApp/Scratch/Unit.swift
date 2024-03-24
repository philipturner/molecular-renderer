//
//  Unit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

// TODO: Refactor the construction of the housing, decomposing it into 'units'.

struct InputUnit {
  // Ordered from bit 0 -> bit 3.
  var operandA: [Rod] = []
  
  // Ordered from bit 0 -> bit 3.
  var operandB: [Rod] = []
  
  var rods: [Rod] {
    operandA +
    operandB
  }
}

// TODO: Store 'broadcast' uncompressed, but make the rods nullable.
struct PropagateUnit {
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // Ordered from bit 0 -> bit 3.
  var query: [Rod] = []
  
  // Stored in a compressed order.
  var broadcast: [Rod] = []
  
  var rods: [Rod] {
    signal +
    query +
    broadcast
  }
}

// TODO: Store 'broadcast' uncompressed, but make the rods nullable.
struct GenerateUnit {
  // Ordered from bit -1 -> bit 3.
  var signal: [Rod] = []
  
  // Ordered from bit 2 -> bit -1.
  var query: [Rod] = []
  
  // Stored in a compressed order.
  var broadcast: [Rod] = []
  
  var rods: [Rod] {
    signal +
    query +
    broadcast
  }
}

struct OutputUnit {
  // Ordered from bit 0 -> bit 3.
  var carry: [Rod] = []
  
  var rods: [Rod] {
    carry
  }
}
