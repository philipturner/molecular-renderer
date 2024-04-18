import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[Entity]] {
  // TODO: Design a revised system using polygonal bearings. Etch out a
  // circular mask using the compiler. Cap the knobs to prevent part
  // separation at 2 GHz.
  
  // Compile the drive system.
  var driveSystem = DriveSystem()
  driveSystem.minimize()
  driveSystem.setVelocitiesToTemperature(2 * 77)
  
  // Transform the list of atoms into an array.
  var systemAtoms: [Entity] = []
  for rigidBody in driveSystem.rigidBodies {
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
      systemAtoms.append(entity)
    }
  }
  
  // Create an animation to detect whether atoms are actually sorted.
  var frames: [[Entity]] = []
  for frameID in 1...720 {
    let maxAtomProgress = systemAtoms.count * frameID / 720
    let arraySlice = systemAtoms[..<maxAtomProgress]
    frames.append(Array(arraySlice))
  }
  return frames
}

