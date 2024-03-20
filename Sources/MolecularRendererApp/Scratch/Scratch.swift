// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Test two-bit logic gates with full MD simulation. Verify that they work
// reliably at room temperature with the proposed actuation mechanism, at up
// to a 3 nm vdW cutoff. How long do they take to switch?
//
// This may require serializing long MD simulations to the disk for playback.
func createGeometry() -> [[Entity]] {
  var systemDesc = SystemDescriptor()
  systemDesc.patternA = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        // 2 or 6
        Origin { 6 * h }
        Plane { h }
        
        Origin { 1.5 * h2k }
        Plane { h2k }
        
        // 6 or 6
        Origin { 6 * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
  systemDesc.patternB = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        // 2 or 6
        Origin { 6 * h }
        Plane { h }
        
        Origin { 1.5 * h2k }
        Plane { h2k }
        
        // 6 or 6
        Origin { 6 * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
  systemDesc.patternC = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        Origin { 2 * h }
        Plane { h }
        
        Origin { 0.5 * h2k }
        Plane { -h2k }
        
        Origin { 6 * h }
        Plane { -h }
      }
      Concave {
        Origin { 11 * h }
        Plane { h }
        
        Origin { 0.5 * h2k }
        Plane { -h2k }
        
        Origin { 5 * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
  
  var system = System(descriptor: systemDesc)
  system.passivate()
  system.minimizeSurfaces()
  
  // Initialize the rigid bodies with thermal velocities, then zero out the
  // drift in bulk momentum.
  do {
    let randomThermalVelocities = system.createRandomThermalVelocities()
    system.setAtomVelocities(randomThermalVelocities)
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.forces = []
    var rigidBodies = system.createRigidBodies(parametersDescriptor: paramsDesc)
    for rigidBodyID in rigidBodies.indices {
      var rigidBody = rigidBodies[rigidBodyID]
      rigidBody.linearMomentum = .zero
      rigidBody.angularMomentum = .zero
      rigidBodies[rigidBodyID] = rigidBody
    }
    let rigidBodyAtomVelocities = rigidBodies.map(\.velocities)
    system.setAtomVelocities(rigidBodyAtomVelocities)
  }
  
  let paramsDesc = MM4ParametersDescriptor()
  // use default forces
  let rigidBodies = system.createRigidBodies(parametersDescriptor: paramsDesc)
  
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  for rigidBodyID in rigidBodies.indices {
    let rigidBody = rigidBodies[rigidBodyID]
    var parameters = rigidBody.parameters
    var boundingBoxMinY: Float = .greatestFiniteMagnitude
    var boundingBoxMaxY: Float = -.greatestFiniteMagnitude
    for atomID in parameters.atoms.indices {
      let position = rigidBody.positions[atomID]
      boundingBoxMinY = min(boundingBoxMinY, position.y)
      boundingBoxMaxY = max(boundingBoxMaxY, position.y)
    }
    if rigidBodyID == 1 {
      boundingBoxMaxY = .signalingNaN
    }
    if rigidBodyID == 2 {
      boundingBoxMinY = .signalingNaN
    }
    
    let frozenRigidBodyIDs: Set<Int> = [0, 1, 2]
    if frozenRigidBodyIDs.contains(rigidBodyID) {
      for atomID in parameters.atoms.indices {
        let centerType = parameters.atoms.centerTypes[atomID]
        guard centerType == .quaternary else {
          continue
        }
        let position = rigidBody.positions[atomID]
        let closenessMin = (position.y - boundingBoxMinY).magnitude
        let closenessMax = (position.y - boundingBoxMaxY).magnitude
        guard closenessMin < 0.5 || closenessMax < 0.5 else {
          continue
        }
        guard Float.random(in: 0..<1) < 0.4 else {
          continue
        }
        parameters.atoms.masses[atomID] = 0
      }
    }
    systemParameters.append(contentsOf: parameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.cutoffDistance = 2.5
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = systemParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  let systemStartPositions = rigidBodies.flatMap(\.positions)
  let systemStartVelocities = rigidBodies.flatMap(\.velocities)
  forceField.positions = systemStartPositions
  forceField.minimize()
  forceField.velocities = systemStartVelocities
  
  var frames: [[Entity]] = []
  for frameID in 0...240 {
    if frameID > 0 {
      forceField.simulate(time: 0.040)
    }
    let kinetic = forceField.energy.kinetic
    let potential = forceField.energy.potential
    print("frame:", frameID, terminator: " | ")
    print("kinetic:", kinetic, terminator: " | ")
    print("potential:", potential)
    
    var frame: [Entity] = []
    for atomID in systemParameters.atoms.indices {
      let atomicNumber = systemParameters.atoms.atomicNumbers[atomID]
      let position = forceField.positions[atomID]
      let element = Element(rawValue: atomicNumber)!
      let entity = Entity(position: position, type: .atom(element))
      frame.append(entity)
    }
    frames.append(frame)
  }
  
  // Next, give the drive walls velocities. Send them through the clocking
  // motion at 100 m/s and time the gate switching time.
  
  return frames
}
