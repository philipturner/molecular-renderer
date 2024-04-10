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

// Archive of code for reference.
#if false
extension Renderer {
  func initializeCompilation(_ closure: () -> Animation) {
    let start = CACurrentMediaTime()
    let provider = closure()
    let end = CACurrentMediaTime()
    
    print("atoms:", provider.atomCount)
    print("frames:", provider.frameCount)
    print("setup time:", String(format: "%.1f", (end - start) * 1e3), "ms")
    
    renderingEngine.setAtomProvider(provider)
  }
}

struct Animation: MRAtomProvider {
  // Stored properties.
  var surface: Surface
  
  // TODO: Simulate the drive system with molecular dynamics. Measure the
  // energy dissipation as a function of clock speed. Pre-compile a simulation
  // of it moving. Also, pre-compile the energy-minimized structures to reduce
  // load times.
  var driveSystem: DriveSystem
  
  // TODO: Script the 'nano' rod being manufactured with tripods + AFM. The
  // reaction sequence doesn't need to be tested in xTB; only the tripod
  // structures need to come from xTB (and they can be pre-compiled as well).
  // - Create a function to compile the tripods pre-minimization, and another
  //   function to retrieve compiled ones from the disk (like with the flywheel
  //   structure).
  var manufacturingSequence: ManufacturingSequence
  
  // TODO: Script the parts being brought together. What order are they placed
  // in, and where do they move in 3D space?
  
  // TODO: Record camera motions in the UI, then load them for replaying in
  // the offline renderer. It is especially tricky to automate the camera
  // motions for the atom placement sequence.
  
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
    driveSystem.connectingRod.minimize()
    driveSystem.flywheel.minimize()
    driveSystem.minimize()
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
    
    // Flip the axes so it's easier to move around.
    for atomID in frame.indices {
      var atom = frame[atomID]
      var position = atom.position
      position = SIMD3(position.x, position.z, -position.y)
      atom.position = position
      frame[atomID] = atom
    }
    
    return frame.map {
      MRAtom(origin: $0.position, element: $0.atomicNumber)
    }
  }
}
#endif
