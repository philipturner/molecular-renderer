//
//  System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/22/24.
//

import HDL
import MM4
import Numerics
import OpenMM

struct System {
  var rod1: Rod!
  var rod2: Rod!
  var housing: Housing!
  
  var forceField: MM4ForceField!
  var rigidBodies: [MM4RigidBody] = []
  
  init() {
    // Create the logic rods.
    rod1 = Rod(lattice: createRod1Lattice())
    rod2 = Rod(lattice: createRod2Lattice())
    
    // Create 'housing'.
    housing = Housing()
    
    // Create 'rigidBodies'.
    createRigidBodies()
    
    // Create 'forceField'.
    createForceField()
  }
  
  // Create rigid bodies, which store the positions, velocities, and even the
  // bonding topologies.
  mutating func createRigidBodies() {
    func createRigidBody(topology: Topology) -> MM4RigidBody {
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      let parameters = try! MM4Parameters(descriptor: paramsDesc)
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = parameters
      rigidBodyDesc.positions = topology.atoms.map(\.position)
      let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      return rigidBody
    }
    
    let rigidBodyRod1 = createRigidBody(topology: rod1.topology)
    let rigidBodyRod2 = createRigidBody(topology: rod2.topology)
    let rigidBodyHousing = createRigidBody(topology: housing.topology)
    rigidBodies.append(rigidBodyRod1)
    rigidBodies.append(rigidBodyRod2)
    rigidBodies.append(rigidBodyHousing)
  }
  
  // Create a force field object to recycle for multiple simulations.
  mutating func createForceField() {
    // Create a single 'MM4Parameters' object from the rigid bodies.
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    for rigidBody in rigidBodies {
      let partParameters = rigidBody.parameters
      systemParameters.append(contentsOf: partParameters)
    }
    
    // Initialize the simulator with these parameters.
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = systemParameters
    forceFieldDesc.integrator = .multipleTimeStep
    forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  }
}

// MARK: - State

extension System {
  // Bring the parts into their initial positions.
  mutating func alignParts() {
    for rigidBodyID in rigidBodies.indices {
      rigidBodies[rigidBodyID].centerOfMass = .zero
    }
    
    rigidBodies[0].rotate(angle: .pi / 2, axis: [0, 1, 0])
    rigidBodies[0].rotate(angle: .pi, axis: [1, 0, 0])
    rigidBodies[0].centerOfMass += SIMD3(-0.46, 0, 1.30)
    
    rigidBodies[1].rotate(angle: .pi / 2, axis: [0, 0, 1])
    rigidBodies[1].centerOfMass += SIMD3(0.46, 1.30, 0)
  }
  
  // Overwrite the rigid bodies with the force field's current state.
  //
  // NOTE: You can treat the force field state as transient. Use it to store
  //       temporary arrays of linearized data. The rigid bodies should always
  //       be the source of truth.
  mutating func updateRigidBodies() {
    var atomCursor: Int = .zero
    for rigidBodyID in rigidBodies.indices {
      // Determine the atom range.
      var rigidBody = rigidBodies[rigidBodyID]
      let nextAtomCursor = atomCursor + rigidBody.parameters.atoms.count
      let atomRange = atomCursor..<nextAtomCursor
      atomCursor += rigidBody.parameters.atoms.count
      
      // Create a new rigid body with the desired state.
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = Array(forceField.positions[atomRange])
      rigidBodyDesc.parameters = rigidBody.parameters
      rigidBodyDesc.velocities = Array(forceField.velocities[atomRange])
      rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
      // Overwrite the current value in the array.
      rigidBodies[rigidBodyID] = rigidBody
    }
  }
  
  // Create a frame for animation.
  func createFrame() -> [Entity] {
    var frame: [Entity] = []
    for rigidBody in rigidBodies {
      for atomID in rigidBody.parameters.atoms.indices {
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
        let position = rigidBody.positions[atomID]
        let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
        frame.append(entity)
      }
    }
    return frame
  }
}

// MARK: - Simulation

extension System {
  // Minimize the potential energy at zero temperature.
  mutating func minimize() {
    forceField.positions = rigidBodies.flatMap(\.positions)
    forceField.minimize()
    updateRigidBodies()
  }
  
  // Equilibriate the thermal potential energy, and save the associated
  // thermal kinetic state.
  mutating func equilibriate(temperature: Double) {
    let equilibriationTime: Double = 1
    
    // Iterate once at twice the energy, then 5 times at the correct energy.
    for iterationID in 0...5 {
      var effectiveTemperature: Double
      if iterationID == 0 {
        effectiveTemperature = temperature * 2
      } else {
        effectiveTemperature = temperature
      }
      setVelocitiesToTemperature(effectiveTemperature)
      
      // Zero out the bulk momenta.
      updateRigidBodies()
      for i in rigidBodies.indices {
        rigidBodies[i].linearMomentum = .zero
        rigidBodies[i].angularMomentum = .zero
      }
      
      // Divide the equilibriation time among the iterations.
      forceField.positions = rigidBodies.flatMap(\.positions)
      forceField.velocities = rigidBodies.flatMap(\.velocities)
      if iterationID == 0 {
        forceField.simulate(time: equilibriationTime / 2)
      } else {
        forceField.simulate(time: equilibriationTime / 10)
      }
    }
    
    // Update the rigid bodies with the final thermal kinetic state.
    updateRigidBodies()
    for i in rigidBodies.indices {
      rigidBodies[i].linearMomentum = .zero
      rigidBodies[i].angularMomentum = .zero
    }
  }
  
  // Create the thermal kinetic state from the Boltzmann distribution.
  //
  // Since the force field is a 'class', this function doesn't have to be
  // 'mutating'. The absence of 'mutating' expresses that this function doesn't
  // update the rigid bodies.
  func setVelocitiesToTemperature(_ temperature: Double) {
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
    
    // Assign the force field state.
    forceField.velocities = velocities
  }
}
