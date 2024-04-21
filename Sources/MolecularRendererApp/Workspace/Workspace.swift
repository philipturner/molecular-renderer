import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Rods (show skeleton of 2-bit HA)
// Patterns (show one rod in detail)
// Drive walls (show before and after actuation)
// Drive walls (GIF)
// Housing (show housing and drive walls, without logic rods inside)
//
// Upload images to GDrive

func createGeometry() -> [[Entity]] {
  let halfAdder = HalfAdder()
  
  var frames: [[Entity]] = []
  for frameID in 0..<240 {
    var rod1 = halfAdder.intermediateUnit.propagate[0]
    var rod2 = halfAdder.intermediateUnit.propagate[1]
    var driveWall = halfAdder.intermediateUnit.driveWall
    
    var progress: Double = .zero
    if frameID < 60 {
      progress = Double(frameID) / 59
    } else if frameID < 120 {
      progress = 1
    } else if frameID < 180 {
      progress = Double(179 - frameID) / 59
    }
    
    rod1.rigidBody.centerOfMass.x += progress * 3.25 * 0.3567
    rod2.rigidBody.centerOfMass.x += progress * 3.25 * 0.3567
    driveWall.rigidBody.centerOfMass.y += progress * 3.25 * 0.3567
    
    var rigidBodies: [MM4RigidBody] = []
    rigidBodies.append(rod1.rigidBody)
    rigidBodies.append(rod2.rigidBody)
    rigidBodies.append(driveWall.rigidBody)
    
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
    var frame = createFrame(rigidBodies: rigidBodies)
    
    // Reposition the scene, so the user doesn't have to move.
    for atomID in frame.indices {
      var atom = frame[atomID]
      atom.position = SIMD3(-atom.position.x, atom.position.y, -atom.position.z)
      atom.position += SIMD3(7.5, -3.75, -2)
      frame[atomID] = atom
    }
    
    
    // Filter out atoms with a certain coordinate.
    var newFrame: [Entity] = []
    for atom in frame {
      if atom.position.z > -3 {
        continue
      }
      newFrame.append(atom)
    }
    frames.append(newFrame)
  }
  
  return frames
}
