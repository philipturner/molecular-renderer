//
//  Circuit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct Circuit {
  var input = InputUnit()
  var propagate = PropagateUnit()
  var generate = GenerateUnit()
  var intermediate = IntermediateUnit()
  var output = OutputUnit()
  
  var rods: [Rod] {
    input.rods +
    propagate.rods +
    generate.rods +
    intermediate.rods +
    output.rods
  }
  
  init() {
    
  }
}
