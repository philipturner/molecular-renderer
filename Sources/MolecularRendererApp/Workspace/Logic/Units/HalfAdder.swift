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
  var inputUnit: InputUnit
  var intermediateUnit: IntermediateUnit
  var housing: LogicHousing
  
  var rigidBodies: [MM4RigidBody] {
    var output: [MM4RigidBody] = []
    output += [
      housing.rigidBody,
      inputUnit.operandDriveWall.rigidBody,
      inputUnit.sumDriveWall.rigidBody,
      intermediateUnit.driveWall.rigidBody,
    ]
    output.append(contentsOf: inputUnit.rods.map(\.rigidBody))
    output.append(contentsOf: intermediateUnit.rods.map(\.rigidBody))
    return output
  }
  
  init() {
    inputUnit = InputUnit()
    intermediateUnit = IntermediateUnit()
    
    var housingDesc = LogicHousingDescriptor()
    housingDesc.dimensions = SIMD3(22, 17, 14)
    housingDesc.patterns.append(contentsOf: inputUnit.holePatterns)
    housingDesc.patterns.append(contentsOf: intermediateUnit.holePatterns)
    if let housingString = Self.housingString {
      housingDesc.surfaceAtoms = housingString
    }
    housing = LogicHousing(descriptor: housingDesc)
  }
}

extension HalfAdder {
  static let housingString: String? = nil
}
