// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[Entity]] {
  // Demonstrate transmission of a clock signal in one of the 2 available
  // directions. It should demonstrate the sequence of clock phases expected in
  // the full ALU. Measure how short the switching time can be.
  // - Take at least one screenshot to document this experiment.
  
  var system = System()
  system.minimize()
  system.initializeRigidBodies()
  
  // Set up the system for simulation.
  for rodID in system.rods.indices {
    system.rods[rodID].rigidBody!.centerOfMass += SIMD3(0, 0, 0)
  }
  system.driveWall.rigidBody!.centerOfMass += SIMD3(0, -2.2, 0)
  
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(system.housing.rigidBody!)
  for rod in system.rods {
    rigidBodies.append(rod.rigidBody!)
  }
  rigidBodies.append(system.driveWall.rigidBody!)
  
  var fire = FIRE()
  fire.anchors = [0, 5]
  fire.rigidBodies = rigidBodies
  let result = fire.minimize()
  let forceField = fire.forceField!
  var frames = result.frames
  rigidBodies = fire.rigidBodies
  for i in rigidBodies.indices {
    rigidBodies[i].linearMomentum = .zero
    rigidBodies[i].angularMomentum = .zero
  }
  
  var movedPosition: Double = .zero
  var reversedDirection = false
  for frameID in 0..<1500 {
    // Update the positions in the forcefield.
    forceField.positions = rigidBodies.flatMap(\.positions)
    
    // Assign forces.
    let forces = forceField.forces
    var cursor = 0
    for rigidBodyID in rigidBodies.indices {
      let spacing = rigidBodies[rigidBodyID].parameters.atoms.count
      let range = cursor..<(cursor + spacing)
      cursor += spacing
      rigidBodies[rigidBodyID].forces = Array(forces[range])
    }
    
    // Perform MD integration.
    for i in rigidBodies.indices {
      if i >= 1 && i <= 4 {
        rigidBodies[i].linearMomentum += 0.040 * rigidBodies[i].netForce!
        rigidBodies[i].angularMomentum += 0.040 * rigidBodies[i].netTorque!
        
        // Dampen the kinetic energy, emulating thermal energy dissipation from
        // bonded forces.
        rigidBodies[i].linearMomentum *= 0.95
        rigidBodies[i].angularMomentum *= 0.95
        
        let v = rigidBodies[i].linearMomentum / rigidBodies[i].mass
        let w = rigidBodies[i].angularMomentum / rigidBodies[i].momentOfInertia
        let angularSpeed = (w * w).sum().squareRoot()
        rigidBodies[i].centerOfMass += 0.040 * v
        rigidBodies[i].rotate(angle: 0.040 * angularSpeed)
      } else if i == 5 {
        let v: Double = 0.050
        if reversedDirection {
          rigidBodies[i].centerOfMass.y -= 0.040 * v
        } else {
          movedPosition += 0.040 * v
          if movedPosition < 2.3 {
            rigidBodies[i].centerOfMass.y += 0.040 * v
          } else {
            reversedDirection = true
            print("switching time: \(0.040 * Double(frameID)) ps")
          }
        }
      }
    }
    
    // Record the frame.
    var output: [Entity] = []
    for rigidBody in rigidBodies {
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let storage = SIMD4(position, Float(atomicNumber))
        let entity = Entity(storage: storage)
        output.append(entity)
      }
    }
    frames.append(output)
  }
  return frames
}
