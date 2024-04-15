import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [[MM4RigidBody]] {
  // Declare a program constant for the flywheel start frequency.
  let flywheelFrequencyInGHz: Double = 10.0
  
  // Declare a program constant for the equilibriation time.
  let equilibriationTimeInPs: Double = 5.0
  
  // Declare a state variable that tracks energy drift.
  var initialSystemEnergy: Double?
  
  // Compile the drive system.
  var driveSystem = DriveSystem()
  driveSystem.minimize()
  driveSystem.setVelocitiesToTemperature(2 * 298)
  
  // Header for the log file.
  print("simulation of flywheel system")
  print("- all quantities in nm-yg-ps system (see MM4 docs for info)")
  print("- system components")
  print("  - rigidBodies[0]: connecting rod")
  print("  - rigidBodies[1]: flywheel")
  print("  - rigidBodies[2]: housing")
  print("  - rigidBodies[3]: piston")
  var rigidBodies = driveSystem.rigidBodies
  
  var forceFieldParameters = rigidBodies[0].parameters
  var forceFieldPositions = rigidBodies[0].positions
  var forceFieldVelocities = rigidBodies[0].velocities
  for rigidBody in rigidBodies[1...] {
    forceFieldParameters.append(contentsOf: rigidBody.parameters)
    forceFieldPositions.append(contentsOf: rigidBody.positions)
    forceFieldVelocities.append(contentsOf: rigidBody.velocities)
  }
  
  // Create a system rigid body for zeroing out the entire system's momentum.
  var systemRigidBodyDesc = MM4RigidBodyDescriptor()
  systemRigidBodyDesc.parameters = forceFieldParameters
  systemRigidBodyDesc.positions = forceFieldPositions
  systemRigidBodyDesc.velocities = forceFieldVelocities
  var systemRigidBody = try! MM4RigidBody(descriptor: systemRigidBodyDesc)
  
  // Create the forcefield, using the system rigid body as the source of truth.
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = systemRigidBody.parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = systemRigidBody.positions
  forceField.velocities = systemRigidBody.velocities
  print()
  print("forcefield: MM4")
  print("- integrator: MTS (single precision)")
  print("- time step (bonded):", String(format: "%.5f", forceField.timeStep / 2))
  print("- time step (nonbonded):", String(format: "%.5f", forceField.timeStep))
  print("- nonbonded cutoff:", String(format: "%.2f", forceFieldDesc.cutoffDistance ?? 1.00))
  print("- dielectric constant:", String(format: "%.2f", forceFieldDesc.dielectricConstant))
  print("- forces: bend, external, nonbonded, stretch, stretch-bend")
  
  print()
  print("potential energy minimization")
  print("- accuracy: 10 zJ")
  
  // Loop over the simulation frames.
  var frames: [[MM4RigidBody]] = []
  for frameID in -2...100 {
    // Report the frame ID.
    let timeStep: Double = 0.400
    print()
    print("simulation frame:", frameID)
    
    var timeStamp: Double
    if frameID == -2 {
      // The first frame is the initial state.
      timeStamp = -equilibriationTimeInPs
    } else if frameID == -1 {
      // The second frame is 1 ps of equilibriation.
      forceField.simulate(time: equilibriationTimeInPs)
      timeStamp = 0
    } else if frameID == 0 {
      // Start spinning the flywheel.
      driveSystem.connectingRod.rigidBody = rigidBodies[0]
      driveSystem.flywheel.rigidBody = rigidBodies[1]
      driveSystem.housing.rigidBody = rigidBodies[2]
      driveSystem.piston.rigidBody = rigidBodies[3]
      driveSystem.initializeFlywheel(frequencyInGHz: flywheelFrequencyInGHz)
      
      // Update the forcefield and state variables.
      rigidBodies = driveSystem.rigidBodies
      forceField.positions = rigidBodies.flatMap(\.positions)
      forceField.velocities = rigidBodies.flatMap(\.velocities)
      let energy = forceField.energy
      initialSystemEnergy = energy.potential + energy.kinetic
      
      timeStamp = 0
    } else {
//      forceField.simulate(time: timeStep)
      
      for i in rigidBodies.indices {
        var rigidBody = rigidBodies[i]
        rigidBody.centerOfMass += timeStep * rigidBody.linearMomentum / rigidBody.mass
        
        let angularVelocity = rigidBody.angularMomentum / rigidBody.momentOfInertia
        var ω: SIMD3<Double> = .zero
        ω += angularVelocity[0] * rigidBody.principalAxes.0
        ω += angularVelocity[1] * rigidBody.principalAxes.1
        ω += angularVelocity[2] * rigidBody.principalAxes.2
        
        let worldSpaceAngularSpeed = (ω * ω).sum().squareRoot()
        var worldSpaceRotationAxis = ω / worldSpaceAngularSpeed
        var isNaN = false
        for i in 0..<3 {
          if worldSpaceRotationAxis[i].isNaN || worldSpaceRotationAxis[i].isInfinite {
            isNaN = true
          }
        }
        if isNaN {
          worldSpaceRotationAxis = .zero
        }
        rigidBody.rotate(angle: timeStep * worldSpaceAngularSpeed, axis: worldSpaceRotationAxis)
        
        rigidBodies[i] = rigidBody
      }
      forceField.positions = rigidBodies.flatMap(\.positions)
      forceField.velocities = rigidBodies.flatMap(\.velocities)
      
      timeStamp = Double(frameID) * timeStep
    }
    print("- time:", String(format: "%.3f", timeStamp))
    
    var systemRigidBodyDesc = MM4RigidBodyDescriptor()
    systemRigidBodyDesc.parameters = systemRigidBody.parameters
    systemRigidBodyDesc.positions = forceField.positions
    systemRigidBodyDesc.velocities = forceField.velocities
    systemRigidBody = try! MM4RigidBody(descriptor: systemRigidBodyDesc)
    
    var atomCursor: Int = .zero
    for rigidBodyID in rigidBodies.indices {
      var rigidBody = rigidBodies[rigidBodyID]
      let atomCount = rigidBody.parameters.atoms.count
      let range = atomCursor..<atomCursor + atomCount
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = Array(forceField.positions[range])
      rigidBodyDesc.velocities = Array(forceField.velocities[range])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
      rigidBodies[rigidBodyID] = rigidBody
      atomCursor += atomCount
    }
    frames.append(rigidBodies)
    
    // Report the energy.
    let energy = DriveSystemEnergy(
      forceField: forceField, rigidBodies: rigidBodies)
    energy.display(initialSystemEnergy: initialSystemEnergy)
    
    // Report the net momentum of the system.
    print("- system")
    display(rigidBody: systemRigidBody)
    
    // Report the rigid body attributes.
    for rigidBodyID in rigidBodies.indices {
      let rigidBody = rigidBodies[rigidBodyID]
      let partEnergy = DriveSystemPartEnergy(rigidBody: rigidBody)
      
      print("- rigidBodies[\(rigidBodyID)]")
      display(rigidBody: rigidBody)
      partEnergy.display()
    }
  }
  return frames
}

// Display the bulk attributes of the rigid body.
func display(rigidBody: MM4RigidBody) {
  // Report the mass and center of mass.
  let mass = rigidBody.mass
  let centerOfMass = rigidBody.centerOfMass
  print("  - atoms:", rigidBody.parameters.atoms.count)
  print("  - mass:", String(format: "%.1f", mass))
  print("  - center of mass: (\(String(format: "%.3f", centerOfMass.x)), \(String(format: "%.3f", centerOfMass.y)), \(String(format: "%.3f", centerOfMass.z)))")
  
  // Report the diagonalized inertia tensor matrix.
  let (axis0, axis1, axis2) = rigidBody.principalAxes
  let principalAxes = [axis0, axis1, axis2]
  let momentOfInertia = rigidBody.momentOfInertia
  print("  - moment of inertia:")
  for axisID in 0..<3 {
    let axis = principalAxes[axisID]
    print("    - Σ[\(axisID)]: (\(String(format: "%.4f", axis.x)), \(String(format: "%.4f", axis.y)), \(String(format: "%.4f", axis.z)))")
  }
  print("    - Λ[0]: \(String(format: "%.1f", momentOfInertia[0]))")
  print("    - Λ[1]: \(String(format: "%.1f", momentOfInertia[1]))")
  print("    - Λ[2]: \(String(format: "%.1f", momentOfInertia[2]))")
  
  // Report the linear momentum.
  let linearMomentum = rigidBody.linearMomentum
  let linearVelocity = linearMomentum / rigidBody.mass
  let linearVelocitySI = linearVelocity / 0.001
  print("  - linear momentum:")
  print("    - p: (\(Float(linearMomentum.x)), \(Float(linearMomentum.y)), \(Float(linearMomentum.z)))")
  print("    - v: (\(Float(linearVelocity.x)), \(Float(linearVelocity.y)), \(Float(linearVelocity.z))) nm/ps")
  print("    - v: (\(Float(linearVelocitySI.x)), \(Float(linearVelocitySI.y)), \(Float(linearVelocitySI.z))) m/s")
  
  // Report the angular momentum.
  let angularMomentum = rigidBody.angularMomentum
  let angularVelocity = angularMomentum / rigidBody.momentOfInertia
  let angularVelocityGHz = angularVelocity / (2 * Double.pi * 0.001)
  print("  - angular momentum:")
  print("    - L: (\(Float(angularMomentum.x)), \(Float(angularMomentum.y)), \(Float(angularMomentum.z)))")
  print("    - ω: (\(Float(angularVelocity.x)), \(Float(angularVelocity.y)), \(Float(angularVelocity.z))) rad/ps")
  print("    - ω: (\(Float(angularVelocityGHz.x)), \(Float(angularVelocityGHz.y)), \(Float(angularVelocityGHz.z))) GHz")
}
