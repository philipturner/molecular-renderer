//
//  Animation.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/5/24.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

struct Animation: MRAtomProvider {
  // Stored properties.
  var surface: Surface
  var driveSystem: DriveSystem
  var manufacturingSequence: ManufacturingSequence
  // TODO: AssemblySequence
  
  // Computed properties.
  var atomCount: Int {
    var output: Int = .zero
    output += surface.topology.atoms.count
    output += driveSystem.connectingRod.rigidBody.positions.count
    output += driveSystem.flywheel.rigidBody.positions.count
    output += driveSystem.housing.rigidBody.positions.count
    output += driveSystem.piston.rigidBody.positions.count
    return output
  }
  var frameCount: Int {
    manufacturingSequence.frameCount
  }
  
  // Object initializer.
  init() {
    surface = Surface()
    driveSystem = DriveSystem()
    manufacturingSequence = ManufacturingSequence(driveSystem: driveSystem)
    
    // Phases:
    // - Manufacturing
    // - Assembly
    // - Operation
  }
  
  
}

extension Animation {
  func atoms(time: MRTime) -> [MRAtom] {
    var frameID = 4 * time.absolute.frames
    frameID = min(frameID, frameCount - 1)
    
    var frame: [Entity] = []
    frame += surface.topology.atoms
    frame += manufacturingSequence.atoms(frameID: frameID)
    
    let cameraPosition = manufacturingSequence
      .cameraPosition(frameID: frameID)
    for atomID in frame.indices {
      var atom = frame[atomID]
      atom.position -= cameraPosition
      frame[atomID] = atom
    }
    
    return frame.map {
      MRAtom(origin: $0.position, element: $0.atomicNumber)
    }
  }
}
