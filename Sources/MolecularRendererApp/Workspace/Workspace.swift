import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createFrame(rigidBodies: [MM4RigidBody]) -> [Entity] {
  var atoms: [Entity] = []
  for rigidBody in rigidBodies {
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      atoms.append(Entity(storage: storage))
    }
  }
  return atoms
}

func createGeometry() -> [[Entity]] {
  var surface = Surface()
  var system = DriveSystem()
  
  system.connectingRod.rigidBody.centerOfMass = SIMD3(0, 20, 0)
  system.flywheel.rigidBody.centerOfMass = SIMD3(-10, 12, 0)
  system.housing.rigidBody.centerOfMass = SIMD3(0, 0, 0)
  system.piston.rigidBody.centerOfMass = SIMD3(10, 12, 0)
  
  func alignZ(rigidBody: inout MM4RigidBody) {
    var minZ: Float = .greatestFiniteMagnitude
    for position in rigidBody.positions {
      minZ = min(minZ, position.z)
    }
    let deltaZ: Float = 0.690 - minZ
    rigidBody.centerOfMass.z += Double(deltaZ)
  }
  alignZ(rigidBody: &system.connectingRod.rigidBody)
  alignZ(rigidBody: &system.flywheel.rigidBody)
  alignZ(rigidBody: &system.housing.rigidBody)
  alignZ(rigidBody: &system.piston.rigidBody)
  
  // Collect up all the atoms, in the order they will be assembled.
  //
  // TODO: Separate into different functions for different parts, so they can
  // be manufactured at different speeds.
  let systemAtoms: [Entity] = createFrame(rigidBodies: [
    system.connectingRod.rigidBody,
    system.flywheel.rigidBody,
    system.piston.rigidBody,
    system.housing.rigidBody,
  ])
  
  // Phases:
  // - Manufacturing
  // - Assembly
  // - Operation
  //
  // TODO: Split the 'Animation' into its own data structure.
  var frames: [[Entity]] = []
  let manufacturingFrameCount: Int = 120 * 10
  for frameID in 0..<manufacturingFrameCount {
    var progress = systemAtoms.count
    progress *= frameID
    progress /= (manufacturingFrameCount - 1)
    
    var frame: [Entity] = []
    frame += surface.topology.atoms
    for atomID in systemAtoms.indices {
      let atom = systemAtoms[atomID]
      guard atomID < progress else {
        continue
      }
      frame.append(atom)
    }
    frames.append(frame)
    
    print(frame.count)
  }
  
  return frames
}
