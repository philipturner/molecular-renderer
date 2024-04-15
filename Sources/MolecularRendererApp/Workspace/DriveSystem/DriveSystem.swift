//
//  DriveSystem.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/3/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct DriveSystem {
  var connectingRod: ConnectingRod
  var flywheel: Flywheel
  var housing: DriveSystemHousing
  var piston: Piston
  
  var rigidBodies: [MM4RigidBody] {
    var output: [MM4RigidBody] = []
    output.append(connectingRod.rigidBody)
    output.append(flywheel.rigidBody)
    output.append(housing.rigidBody)
    output.append(piston.rigidBody)
    return output
  }
  
  init() {
    connectingRod = ConnectingRod()
    flywheel = Flywheel()
    housing = DriveSystemHousing()
    piston = Piston()
    
    let latticeConstant = Double(Constant(.square) { .elemental(.carbon) })
    let flywheelOffset = SIMD3(10, 10, 10.3) * latticeConstant
    let pistonOffset = SIMD3(28.5, 10, 10.3) * latticeConstant
    let connectingRodOffset = SIMD3(-2.5, 10.3, 17.4) * latticeConstant
    
    flywheel.rigidBody.centerOfMass += flywheelOffset
    piston.rigidBody.centerOfMass += pistonOffset
    connectingRod.rigidBody.centerOfMass += connectingRodOffset
    connectingRod.rigidBody.centerOfMass.x -= 0.2
    piston.rigidBody.centerOfMass.x += 0.35
    
    let housingCenter = housing.rigidBody.centerOfMass
    connectingRod.rigidBody.centerOfMass -= housingCenter
    flywheel.rigidBody.centerOfMass -= housingCenter
    housing.rigidBody.centerOfMass -= housingCenter
    piston.rigidBody.centerOfMass -= housingCenter
  }
  
  mutating func rotate(angle: Double, axis: SIMD3<Double>) {
    let quaternion = Quaternion(angle: angle, axis: axis)
    
    func rotate(rigidBody: inout MM4RigidBody) {
      var centerOfMass = rigidBody.centerOfMass
      rigidBody.centerOfMass -= centerOfMass
      rigidBody.rotate(angle: angle, axis: axis)
      centerOfMass = quaternion.act(on: centerOfMass)
      rigidBody.centerOfMass += centerOfMass
    }
    rotate(rigidBody: &connectingRod.rigidBody)
    rotate(rigidBody: &flywheel.rigidBody)
    rotate(rigidBody: &housing.rigidBody)
    rotate(rigidBody: &piston.rigidBody)
  }
  
  mutating func scale(factor: SIMD3<Double>) {
    connectingRod.rigidBody.centerOfMass *= factor
    flywheel.rigidBody.centerOfMass *= factor
    housing.rigidBody.centerOfMass *= factor
    piston.rigidBody.centerOfMass *= factor
  }
  
  mutating func shift(offset: SIMD3<Double>) {
    connectingRod.rigidBody.centerOfMass += offset
    flywheel.rigidBody.centerOfMass += offset
    housing.rigidBody.centerOfMass += offset
    piston.rigidBody.centerOfMass += offset
  }
}

extension DriveSystem {
  mutating func minimize() {
    var forceFieldParameters = connectingRod.rigidBody.parameters
    forceFieldParameters.append(contentsOf: flywheel.rigidBody.parameters)
    forceFieldParameters.append(contentsOf: housing.rigidBody.parameters)
    forceFieldParameters.append(contentsOf: piston.rigidBody.parameters)
    
    var forceFieldPositions = connectingRod.rigidBody.positions
    forceFieldPositions += flywheel.rigidBody.positions
    forceFieldPositions += housing.rigidBody.positions
    forceFieldPositions += piston.rigidBody.positions
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = forceFieldParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = forceFieldPositions
    forceField.minimize(tolerance: 10)
    
    var atomCursor: Int = .zero
    func update(rigidBody: inout MM4RigidBody) {
      let nextAtomCursor = atomCursor + rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      atomCursor = nextAtomCursor
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    update(rigidBody: &connectingRod.rigidBody)
    update(rigidBody: &flywheel.rigidBody)
    update(rigidBody: &housing.rigidBody)
    update(rigidBody: &piston.rigidBody)
  }
  
  // Create thermal velocities and set average momentum to zero.
  //
  // WARNING: This will erase any previous value for the momentum.
  mutating func setVelocitiesToTemperature(_ temperature: Double) {
    var rigidBodies = [
      connectingRod.rigidBody,
      flywheel.rigidBody,
      housing.rigidBody,
      piston.rigidBody,
    ]
    
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
    context.setVelocitiesToTemperature(temperature)
    
    // Cast the velocities from FP64 to FP32.
    let state = context.state(types: [.velocities])
    let velocitiesObject = state.velocities
    var velocities: [SIMD3<Float>] = []
    for atomID in 0..<velocitiesObject.size {
      let velocity64 = velocitiesObject[atomID]
      let velocity32 = SIMD3<Float>(velocity64)
      velocities.append(velocity32)
    }
    
    var atomCursor: Int = .zero
    for rigidBodyID in rigidBodies.indices {
      // Determine the atom range.
      var rigidBody = rigidBodies[rigidBodyID]
      let nextAtomCursor = atomCursor + rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      atomCursor += rigidBody.parameters.atoms.count
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = rigidBody.positions
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.velocities = Array(velocities[atomRange])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
      // Zero out the momentum.
      rigidBody.linearMomentum = .zero
      rigidBody.angularMomentum = .zero
      
      // Overwrite the current value in the array.
      rigidBodies[rigidBodyID] = rigidBody
    }
    
    connectingRod.rigidBody = rigidBodies[0]
    flywheel.rigidBody = rigidBodies[1]
    housing.rigidBody = rigidBodies[2]
    piston.rigidBody = rigidBodies[3]
  }
  
  // Initialize the flywheel's angular velocity and correct for the shift in
  // net momentum.
  //
  // WARNING: Ensure the drive system's rigid bodies are overwritten with the
  // current state, not just some copies in the calling program.
  mutating func initializeFlywheel(frequencyInGHz: Double) {
    func destroyOrganizedKineticEnergy(rigidBody: inout MM4RigidBody) {
      rigidBody.angularMomentum = .zero
      rigidBody.linearMomentum = .zero
    }
    func destroyThermalKineticEnergy(rigidBody: inout MM4RigidBody) {
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.positions = rigidBody.positions
      
      let atomCount = rigidBody.parameters.atoms.count
      let velocities = [SIMD3<Float>](repeating: .zero, count: atomCount)
      rigidBodyDesc.velocities = velocities
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    func transferThermalKineticEnergy(
      from source: MM4RigidBody,
      to destination: inout MM4RigidBody
    ) {

      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = destination.parameters
      rigidBodyDesc.positions = destination.positions
      
      let atomCount = destination.parameters.atoms.count
      var velocities = [SIMD3<Float>](repeating: .zero, count: atomCount)
      for atomID in 0..<atomCount {
        velocities[atomID] += source.velocities[atomID]
        velocities[atomID] += destination.velocities[atomID]
      }
      rigidBodyDesc.velocities = velocities
      destination = try! MM4RigidBody(descriptor: rigidBodyDesc)
    }
    
    // Zero out the net momentum in every rigid body.
    destroyOrganizedKineticEnergy(rigidBody: &connectingRod.rigidBody)
    destroyOrganizedKineticEnergy(rigidBody: &flywheel.rigidBody)
    destroyOrganizedKineticEnergy(rigidBody: &housing.rigidBody)
    destroyOrganizedKineticEnergy(rigidBody: &piston.rigidBody)
    
    // Save a copy that contains the thermal velocities.
    let copy = self
    
    // Destroy the thermal energy.
    destroyThermalKineticEnergy(rigidBody: &connectingRod.rigidBody)
    destroyThermalKineticEnergy(rigidBody: &flywheel.rigidBody)
    destroyThermalKineticEnergy(rigidBody: &housing.rigidBody)
    destroyThermalKineticEnergy(rigidBody: &piston.rigidBody)
    
    // Choose the axis that the flywheel will rotate around.
    let rotationAxis = flywheel.rigidBody.principalAxes.0
    guard rotationAxis.z > 0.999 else {
      fatalError("Flywheel was not aligned to expected reference frame.")
    }
    
    // Find the values of 'r' and 'l'.
    let flywheelPosition = DriveSystemPartPosition(source: flywheel)
    let pistonPosition = DriveSystemPartPosition(source: piston)
    var rDelta = flywheelPosition.knobCenter - flywheelPosition.bodyCenter
    var lDelta = flywheelPosition.knobCenter - pistonPosition.knobCenter
    rDelta -= (rDelta * rotationAxis).sum() * rotationAxis
    lDelta -= (lDelta * rotationAxis).sum() * rotationAxis
    let r = (rDelta * rDelta).sum().squareRoot()
    let l = (lDelta * lDelta).sum().squareRoot()
    print("value of r:", r)
    print("value of l:", l)
    
    // Set the flywheel's angular speed.
    let ω_f = frequencyInGHz * 0.001 * (2 * .pi)
    do {
      let I = flywheel.rigidBody.momentOfInertia
      let L_f = I * SIMD3(-ω_f, 0, 0)
      flywheel.rigidBody.angularMomentum += L_f
    }
    
    // Set the connecting rod's initial velocity.
    do {
      var rigidBody = connectingRod.rigidBody
      let (axis0, axis1, axis2) = connectingRod.rigidBody.principalAxes
      let principalAxes = [axis0, axis1, axis2]
      
      let v_c = (1.0 / 2) * (r * ω_f)
      let p_c = rigidBody.mass * SIMD3<Double>(0, v_c, 0)
      rigidBody.linearMomentum += p_c
      
      var ω_c: SIMD3<Double> = .zero
      for axisID in 0..<3 {
        let axis = principalAxes[axisID]
        let component = (axis * rotationAxis).sum() * (-r / l) * ω_f
        ω_c[axisID] = component
      }
      let L_c = rigidBody.momentOfInertia * ω_c
      rigidBody.angularMomentum += L_c
      
      connectingRod.rigidBody = rigidBody
    }
    
    // Restore the system's net momentum to zero.
    // - What does this do when temperature is zero? Do the objects gain a
    //   temperature that isn't 0 K?
    do {
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
      systemRigidBody.linearMomentum = .zero
      // systemRigidBody.angularMomentum = .zero
      
      var atomCursor: Int = .zero
      func save(rigidBody: inout MM4RigidBody) {
        let atomCount = rigidBody.parameters.atoms.count
        let range = atomCursor..<atomCursor + atomCount
        
        var rigidBodyDesc = MM4RigidBodyDescriptor()
        rigidBodyDesc.parameters = rigidBody.parameters
        rigidBodyDesc.positions = Array(systemRigidBody.positions[range])
        rigidBodyDesc.velocities = Array(systemRigidBody.velocities[range])
        rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
        
        // TODO: Save these stats in a Git commit
        /*
         not zeroing system momentum
         0.0017038408244047787 9.25970276134981e-06 
         SIMD3<Double>(0.0008456707000732422, 17684.417320251465, 0.000394617673009634)
         SIMD3<Double>(-48063.14855957031, 342.2458446472883, -30.85589838027954)
         
         -0.00010644568828865886 -4.375861183008864e-07 
         SIMD3<Double>(-0.01177978515625, 0.359893798828125, 0.0019060969352722168)
         SIMD3<Double>(-2015476.58203125, -0.0018298625946044922, -0.0024433135986328125)
         
         1.9116238601532217e-12 5.774583878371203e-16 
         SIMD3<Double>(-0.0005048187086189593, 0.0009382661717216578, -2.96142016595613e-05)
         SIMD3<Double>(0.024202661997378527, -0.0004710905840088486, 0.00023963549309891086)
         
         4.521011185116796e-15 1.2805236476023636e-17 
         SIMD3<Double>(1.1681978143940341e-05, -9.348675955678232e-05, -7.286454021482314e-06)
         SIMD3<Double>(-0.00018129698679025807, 2.629742545390279e-06, -1.466757803190305e-06)
         
         only zeroing linear momentum
         0.0015588613985073607 8.471796772073958e-06 
         SIMD3<Double>(0.0006515681743621826, 17150.900577545166, 0.0002763736993074417)
         SIMD3<Double>(-48310.77996826172, 82.86233305931091, -22.64497995376587)
         
         -0.0021856362000107765 -8.984901842027118e-06 
         SIMD3<Double>(0.02117919921875, -5750.9022216796875, 0.0017375946044921875)
         SIMD3<Double>(-2015232.88671875, -0.0030548572540283203, 0.00514984130859375)
         
         0.00010343300244337444 3.1244773663432173e-08 
         SIMD3<Double>(-0.005545767501018872, -10373.364794671535, -0.002157924074012385)
         SIMD3<Double>(-0.005461079477072417, -7.177718078862916e-05, -0.00011689878473220006)
         
         9.091149477970732e-06 2.574961975045116e-08 
         SIMD3<Double>(-0.0004905072541987465, -1026.5856609344482, -0.00020443643074941065)
         SIMD3<Double>(-0.0004371463934376152, 7.4203999380628716e-06, -4.071759946100428e-06)
         
         zeroing both momenta
         0.0009419636987502145 5.119201123412276e-06
         SIMD3<Double>(-107.73126522451639, 13285.765525817871, -60.40103794634342)
         SIMD3<Double>(-36231.08125305176, -66.87620458006859, 172.40568614006042)
         
         0.002447681217745412 1.0062139107097284e-05
         SIMD3<Double>(22.30645751953125, -63636.8779296875, -301.8648986816406)
         SIMD3<Double>(-1867757.64453125, 2075.125825405121, 27960.747409820557)
         
         0.0006813672544012661 2.058256566331115e-07
         SIMD3<Double>(123.8844587802887, 43907.69394028187, 336.57002687454224)
         SIMD3<Double>(1223462.7314510345, -10740.794848144054, 28726.509752333164)
         
         0.0001437471903713572 4.071471381289369e-07
         SIMD3<Double>(-38.46467113494873, 6443.2836969047785, 25.695476353168488)
         SIMD3<Double>(19299.79107284546, -213.65057826042175, 600.1659439676441)
         */
        print(DriveSystemPartEnergy(rigidBody: rigidBody).thermalKinetic,
              DriveSystemPartEnergy(rigidBody: rigidBody).temperature,
              rigidBody.linearMomentum,
              rigidBody.angularMomentum)
        
        atomCursor += atomCount
      }
      save(rigidBody: &connectingRod.rigidBody)
      save(rigidBody: &flywheel.rigidBody)
      save(rigidBody: &housing.rigidBody)
      save(rigidBody: &piston.rigidBody)
    }
    
    // Add the thermal energy back in.
    transferThermalKineticEnergy(
      from: copy.connectingRod.rigidBody, to: &connectingRod.rigidBody)
    transferThermalKineticEnergy(
      from: copy.flywheel.rigidBody, to: &flywheel.rigidBody)
    transferThermalKineticEnergy(
      from: copy.housing.rigidBody, to: &housing.rigidBody)
    transferThermalKineticEnergy(
      from: copy.piston.rigidBody, to: &piston.rigidBody)
  }
}
