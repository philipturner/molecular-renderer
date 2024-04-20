//
//  CLA.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct CLA {
  var inputUnit = CLAInputUnit()
  var generateUnit = CLAGenerateUnit()
  var propagateUnit = CLAPropagateUnit()
  var carryUnit = CLACarryUnit()
  var outputUnit = CLAOutputUnit()
  
  var rods: [Rod] {
    inputUnit.rods +
    generateUnit.rods +
    propagateUnit.rods +
    carryUnit.rods +
    outputUnit.rods
  }
  
  init() {
    
  }
}
