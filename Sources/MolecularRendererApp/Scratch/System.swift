//
//  System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/18/24.
//

import Foundation
import HDL
import MM4

// A configuration for a system.
struct SystemDescriptor {
  // An HDL description of the knobs for each rod.
  var patternA: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
  var patternB: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
  var patternC: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
}

struct System {
  var housing: Housing
  var rodA: Rod
  var rodB: Rod
  var rodC: Rod
  var inputDriveWall: DriveWall
  var outputDriveWall: DriveWall
  
  init(descriptor: SystemDescriptor) {
    // Create 'housing'.
    housing = Housing()
    
    // Create 'rodA'.
    var rodDescriptor = RodDescriptor()
    rodDescriptor.length = 14
    rodDescriptor.pattern = descriptor.patternA
    rodA = Rod(descriptor: rodDescriptor)
    
    // Create 'rodB'.
    rodDescriptor.length = 14
    rodDescriptor.pattern = descriptor.patternB
    rodB = Rod(descriptor: rodDescriptor)
    
    // Create 'rodC'.
    rodDescriptor.length = 23
    rodDescriptor.pattern = descriptor.patternC
    rodC = Rod(descriptor: rodDescriptor)
    
    // Create 'inputDriveWall'.
    var driveWallDescriptor = DriveWallDescriptor()
    driveWallDescriptor.cellCount = 2
    inputDriveWall = DriveWall(descriptor: driveWallDescriptor)
    
    // Create 'outputDriveWall'.
    driveWallDescriptor.cellCount = 1
    outputDriveWall = DriveWall(descriptor: driveWallDescriptor)
    
    alignParts()
  }
  
  mutating func alignParts() {
  // Shift the housing down by ~2 cells, to match the extension in the Y
    // direction.
    for atomID in housing.topology.atoms.indices {
      var atom = housing.topology.atoms[atomID]
      var position = atom.position
      position += SIMD3(0, -4 * 0.357, 0)
      atom.position = position
      housing.topology.atoms[atomID] = atom
    }
    
    // Align the rod with the housing.
    for atomID in rodA.topology.atoms.indices {
      var atom = rodA.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      
      // Set Z to either 0 or -0.8, to visualize ends of the clock cycle.
      position += SIMD3(0.91, 0.85, -0.4)
      atom.position = position
      rodA.topology.atoms[atomID] = atom
    }
    
    // Align the rod with the housing.
    for atomID in rodB.topology.atoms.indices {
      var atom = rodB.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      
      // Set Z to either 0 or -0.8, to visualize ends of the clock cycle.
      position += SIMD3(0.91 + 6 * 0.357, 0.85, -0.4)
      atom.position = position
      rodB.topology.atoms[atomID] = atom
    }
    
    // Align the rod with the housing.
    for atomID in rodC.topology.atoms.indices {
      var atom = rodC.topology.atoms[atomID]
      var position = atom.position
      
      // Set X to either 0 or -0.8, to visualize ends of the clock cycle.
      position += SIMD3(0, 1.83, 0.91)
      atom.position = position
      rodC.topology.atoms[atomID] = atom
    }
    
    // Align the drive wall with the housing.
    for atomID in inputDriveWall.topology.atoms.indices {
      var atom = inputDriveWall.topology.atoms[atomID]
      var position = atom.position
      
      // Set Y to either 0 or -2.2, to visualize ends of the clock cycle.
      position += SIMD3(-1.7, 0, -0.1)
      position = SIMD3(position.z, position.y, position.x)
      atom.position = position
      inputDriveWall.topology.atoms[atomID] = atom
    }
    
    // Align the drive wall with the housing.
    for atomID in outputDriveWall.topology.atoms.indices {
      var atom = outputDriveWall.topology.atoms[atomID]
      var position = atom.position
      
      // Set Y to either 1 or -1.2, to visualize ends of the clock cycle.
      position += SIMD3(-1.7, 1, -0.1)
      atom.position = position
      outputDriveWall.topology.atoms[atomID] = atom
    }
  }
  
  mutating func passivate() {
    housing.passivate()
    rodA.passivate()
    rodB.passivate()
    rodC.passivate()
    inputDriveWall.passivate()
    outputDriveWall.passivate()
  }
}
