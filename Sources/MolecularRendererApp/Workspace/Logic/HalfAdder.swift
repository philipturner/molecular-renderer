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

struct HalfAdder {
  var housing: LogicHousing
  var unit: HalfAdderUnit
  
  init() {
    unit = HalfAdderUnit()
    
    var housingDesc = LogicHousingDescriptor()
    housingDesc.dimensions = SIMD3(21, 12, 15)
    housingDesc.patterns = unit.holePatterns
    housingDesc.patterns.append { h, k, l in
      Origin { 20.5 * h }
      Plane { h }
      Replace { .empty }
    }
    housingDesc.patterns.append { h, k, l in
      Origin { 11.75 * k }
      Plane { k }
      Replace { .empty }
    }
    housingDesc.patterns.append { h, k, l in
      Origin { 14.75 * l }
      Plane { l }
      Replace { .empty }
    }
    housing = LogicHousing(descriptor: housingDesc)
  }
}
