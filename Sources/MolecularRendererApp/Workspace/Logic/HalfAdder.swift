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
    output.append(contentsOf: inputUnit.rods.map(\.rigidBody))
    output.append(contentsOf: intermediateUnit.rods.map(\.rigidBody))
    output += [
      housing.rigidBody,
      inputUnit.operandDriveWall.rigidBody,
      inputUnit.sumDriveWall.rigidBody,
      intermediateUnit.driveWall.rigidBody,
    ]
    return output
  }
  
  init() {
    inputUnit = InputUnit()
    intermediateUnit = IntermediateUnit()
    
    // Create the housing.
    
    typealias BoundingPattern = (
      SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
    ) -> Void
    
    var boundingPatterns: [BoundingPattern] = []
    boundingPatterns.append { h, k, l in
      Origin { 22.75 * h }
      Plane { h }
      Replace { .empty }
    }
    boundingPatterns.append { h, k, l in
      Origin { 17.75 * k }
      Plane { k }
      Replace { .empty }
    }
    boundingPatterns.append { h, k, l in
      Origin { 14.75 * l }
      Plane { l }
      Replace { .empty }
    }
    
    var housingDesc = LogicHousingDescriptor()
    housingDesc.dimensions = SIMD3(23, 18, 15)
    housingDesc.patterns = inputUnit.holePatterns + intermediateUnit.holePatterns
    housingDesc.patterns.append(contentsOf: boundingPatterns)
    housing = LogicHousing(descriptor: housingDesc)
  }
}

extension HalfAdder {
  typealias BoundingPattern = (
    SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
  ) -> Void
  
  static func createBoundingPatterns() -> [BoundingPattern] {
    var boundingPatterns: [BoundingPattern] = []
    boundingPatterns.append { h, k, l in
      Origin { 22.75 * h }
      Plane { h }
      Replace { .empty }
    }
    boundingPatterns.append { h, k, l in
      Origin { 17.75 * k }
      Plane { k }
      Replace { .empty }
    }
    boundingPatterns.append { h, k, l in
      Origin { 14.75 * l }
      Plane { l }
      Replace { .empty }
    }
    return boundingPatterns
  }
}
