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
    system.rods[rodID].rigidBody!.centerOfMass += SIMD3(0, 0, -0.5)
  }
  
  // Start with a short rigid body dynamics simulation, with the housing and
  // drive wall positionally constrained. Test whether the rods fall into their
  // lowest-energy state.
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies.append(system.housing.rigidBody!)
  for rod in system.rods {
    rigidBodies.append(rod.rigidBody!)
  }
  rigidBodies.append(system.driveWall.rigidBody!)
  
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  for rigidBody in rigidBodies {
    systemParameters.append(contentsOf: rigidBody.parameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = systemParameters
  forceFieldDesc.cutoffDistance = 2
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  func createFrame(rigidBodies: [MM4RigidBody]) -> [Entity] {
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
    return output
  }
  
  var frames: [[Entity]] = []
  frames.append(createFrame(rigidBodies: rigidBodies))
  for frameID in 0..<600 {
    forceField.positions = rigidBodies.flatMap(\.positions)
    print("frame: \(frameID)")
    
    let forces = forceField.forces
    var cursor = 0
    
    for rigidBodyID in rigidBodies.indices {
      let spacing = rigidBodies[rigidBodyID].parameters.atoms.count
      let range = cursor..<(cursor + spacing)
      cursor += spacing
      
      var copy = rigidBodies[rigidBodyID]
      copy.forces = Array(forces[range])
      copy.linearMomentum += 0.040 * copy.netForce!
      copy.angularMomentum += 0.040 * copy.netTorque!
      
      if rigidBodyID == 0 || rigidBodyID == 5 {
        copy.linearMomentum = .zero
        copy.angularMomentum = .zero
      }
      
      let velocity = copy.linearMomentum / copy.mass
      let angularVelocity = copy.angularMomentum / copy.momentOfInertia
      let angularSpeed = (angularVelocity * angularVelocity).sum().squareRoot()
      copy.centerOfMass += 0.040 * velocity
      copy.rotate(angle: 0.040 * angularSpeed)
      rigidBodies[rigidBodyID] = copy
    }
    frames.append(createFrame(rigidBodies: rigidBodies))
  }
  
  // Demonstrate rigid body energy minimization with FIRE. This is a proof of
  // concept for the DFT simulator. Use INQ as a reference, then incorporate the
  // improvements from FIRE 2.0 and ABC.
  
  return frames
}
