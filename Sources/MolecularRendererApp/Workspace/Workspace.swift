import Foundation
import HDL
import MM4
import Numerics
import OpenMM

import QuartzCore

func createGeometry() -> [[MM4RigidBody]] {
  let housing = Housing()
  let flywheel = Flywheel()
  
  var rigidBodies: [MM4RigidBody] = []
  rigidBodies = [housing.rigidBody, flywheel.rigidBody]
  for rigidBodyID in rigidBodies.indices {
    var rigidBody = rigidBodies[rigidBodyID]
    rigidBody.centerOfMass = .zero
    rigidBodies[rigidBodyID] = rigidBody
  }
  rigidBodies[1].centerOfMass.z += 10
  
  var forceField: MM4ForceField
  var forceField2: MM4ForceField
  do {
    var forceFieldParameters = rigidBodies[0].parameters
    forceFieldParameters.append(contentsOf: rigidBodies[1].parameters)
    var forceFieldPositions = rigidBodies.flatMap(\.positions)
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = forceFieldParameters
    forceFieldDesc.cutoffDistance = 1
    forceFieldDesc.integrator = .multipleTimeStep
    forceField2 = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField2.positions = forceFieldPositions
    forceField2.minimize()
    
    forceFieldPositions = forceField2.positions
    forceFieldDesc.cutoffDistance = 2
    forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = forceFieldPositions
  }
  
  // MARK: - Write to Rigid Bodies
  
  func writeToRigidBodies() {
    let midPoint = rigidBodies[0].parameters.atoms.count
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = rigidBodies[0].parameters
    rigidBodyDesc.positions = Array(forceField.positions[..<midPoint])
    rigidBodyDesc.velocities = Array(forceField.velocities[..<midPoint])
    rigidBodies[0] = try! MM4RigidBody(descriptor: rigidBodyDesc)
    
    rigidBodyDesc.parameters = rigidBodies[1].parameters
    rigidBodyDesc.positions = Array(forceField.positions[midPoint...])
    rigidBodyDesc.velocities = Array(forceField.velocities[midPoint...])
    rigidBodies[1] = try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  
  writeToRigidBodies()
  
  // MARK: - Add Thermal Energy
  
  do {
    // Create a temporary OpenMM system.
    let system = OpenMM_System()
    let positions = OpenMM_Vec3Array(size: 0)
    for rigidBody in rigidBodies {
      for atomID in rigidBody.parameters.atoms.indices {
        let massInYg = rigidBody.parameters.atoms.masses[atomID]
        let massInAmu = massInYg * Float(MM4AmuPerYg)
        system.addParticle(mass: Double(massInAmu))
        
        let positionInNm = rigidBody.positions[atomID]
        positions.append(SIMD3<Double>(positionInNm))
      }
    }
    
    // Fetch the reference platform.
    //
    // NOTE: Using the reference platform for temporary 'OpenMM_Context's
    // reduces the latency. It also avoids annoying OpenCL compiler warnings.
    let platforms = OpenMM_Platform.platforms
    let reference = platforms.first(where: { $0.name == "Reference" })
    guard let reference else {
      fatalError("Could not find reference platform.")
    }
    
    // Use the OpenMM host function for generating thermal velocities.
    let integrator = OpenMM_VerletIntegrator(stepSize: 0)
    let context = OpenMM_Context(
      system: system, integrator: integrator, platform: reference)
    context.positions = positions
    context.setVelocitiesToTemperature(2 * 298)
    
    // Cast the velocities from FP64 to FP32.
    let state = context.state(types: [.velocities])
    let velocitiesObject = state.velocities
    var velocities: [SIMD3<Float>] = []
    for atomID in 0..<velocitiesObject.size {
      let velocity64 = velocitiesObject[atomID]
      let velocity32 = SIMD3<Float>(velocity64)
      velocities.append(velocity32)
    }
    
    // Assign the force field state.
    forceField.velocities = velocities
    
    writeToRigidBodies()
    rigidBodies[0].linearMomentum = .zero
    rigidBodies[0].angularMomentum = .zero
    rigidBodies[1].linearMomentum = .zero
    rigidBodies[1].angularMomentum = .zero
  }
  
  // MARK: - Molecular Dynamics Simulation
  
  rigidBodies[1].centerOfMass.z -= 7.5
  forceField.positions = rigidBodies.flatMap(\.positions)
  
  var frames: [[MM4RigidBody]] = [rigidBodies]
  return frames
  
  #if false
  print("frame: 0")
  
  for frameID in 0..<1000 {
    let checkpoint0 = CACurrentMediaTime()
    var checkpoint1: Double
    
    if frameID == 100 {
      forceField2.positions = forceField.positions
      forceField2.velocities = forceField.velocities
      swap(&forceField, &forceField2)
    }
    
    forceField.simulate(time: 0.040)
    checkpoint1 = CACurrentMediaTime()
    
    writeToRigidBodies()
    
    frames.append(rigidBodies)
    
    let checkpoint2 = CACurrentMediaTime()
    print("frame:", frameID + 1)
    print("time:", checkpoint1 - checkpoint0, checkpoint2 - checkpoint1)
  }
  
  return frames
  #endif
}
