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
  var unit: HalfAdderUnit
  var housing: LogicHousing
  var inputDriveWall: DriveWall
  var outputDriveWall: DriveWall
  var intermediateDriveWall: DriveWall
  
  var rigidBodies: [MM4RigidBody] {
    var output: [MM4RigidBody] = []
    output.append(contentsOf: unit.rods.map(\.rigidBody))
    output += [
      housing.rigidBody,
      inputDriveWall.rigidBody,
      outputDriveWall.rigidBody,
      intermediateDriveWall.rigidBody,
    ]
    return output
  }
  
  init() {
    unit = HalfAdderUnit()
    
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
      Origin { 11.75 * k }
      Plane { k }
      Replace { .empty }
    }
    boundingPatterns.append { h, k, l in
      Origin { 14.75 * l }
      Plane { l }
      Replace { .empty }
    }
    
    var housingDesc = LogicHousingDescriptor()
    housingDesc.dimensions = SIMD3(23, 12, 15)
    housingDesc.patterns = unit.holePatterns
    housingDesc.patterns.append(contentsOf: boundingPatterns)
    housing = LogicHousing(descriptor: housingDesc)
    
    // Create the drive walls.
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    
    var driveWallDesc = DriveWallDescriptor()
    driveWallDesc.dimensions = SIMD3(23, 12, 6)
    driveWallDesc.patterns.append(contentsOf: boundingPatterns)
    driveWallDesc.patterns.append { h, k, l in
      Origin { 13.75 * h }
      Plane { h }
      Replace { .empty }
    }
    inputDriveWall = DriveWall(descriptor: driveWallDesc)
    inputDriveWall.rigidBody.centerOfMass.z -= (6 + 1) * latticeConstant
    
    driveWallDesc.patterns.removeLast()
    driveWallDesc.patterns.append { h, k, l in
      Origin { 14.75 * h }
      Plane { -h }
      Replace { .empty }
    }
    outputDriveWall = DriveWall(descriptor: driveWallDesc)
    outputDriveWall.rigidBody.centerOfMass.z -= (6 + 1) * latticeConstant
    
    driveWallDesc = DriveWallDescriptor()
    driveWallDesc.dimensions = SIMD3(6, 12, 15)
    driveWallDesc.patterns.append(contentsOf: boundingPatterns)
    intermediateDriveWall = DriveWall(descriptor: driveWallDesc)
    intermediateDriveWall
      .rigidBody.centerOfMass.x += (22.75 + 1) * latticeConstant
  }
}
