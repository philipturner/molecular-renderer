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
  // TODO: Create these in separate functions, resulting in nullable values.
  var rod1: Rod
  var rod2: Rod
  var housing: Housing
  
  var forceField: MM4ForceField?
  var rigidBodies: [MM4RigidBody] = []
  
  init() {
    // Create lattices for the logic rods.
    let lattice1 = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Create a sideways groove.
        Concave {
          Origin { 7 * h }
          Plane { h }
          
          Origin { 1.375 * l }
          Plane { l }
          
          Origin { 6 * h }
          Plane { -h }
        }
        Replace { .empty }
        
        // Create silicon dopants to stabilize the groove.
        Concave {
          Origin { 7 * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 1 * l }
          Plane { l }
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 1 * h2k }
          Plane { -h2k }
        }
        Concave {
          Origin { (7 + 5) * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 1 * l }
          Plane { l }
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 1 * h2k }
          Plane { -h2k }
        }
        Replace { .atom(.silicon) }
      }
    }
    let lattice2 = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Create a sideways groove.
        Concave {
          Origin { 7 * h }
          Plane { h }
          
          Origin { 0.5 * l }
          Plane { -l }
          
          Origin { 6 * h }
          Plane { -h }
        }
        Replace { .empty }
        
        // Create silicon dopants to stabilize the groove.
        Concave {
          Origin { 7 * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 0.6 * l }
          Plane { -l }
          Origin { -0.5 * l }
          Plane { l }
          
          Origin { 1 * h2k }
          Plane { -h2k }
        }
        Concave {
          Origin { (7 + 5) * h }
          Plane { h }
          Origin { 1 * h }
          Plane { -h }
          
          Origin { 0.6 * l }
          Plane { -l }
          Origin { -0.5 * l }
          Plane { l }
          
          Origin { 1 * h2k }
          Plane { -h2k }
        }
        Replace { .atom(.silicon) }
      }
    }
    
    // Create the logic rods.
    rod1 = Rod(lattice: lattice1)
    rod2 = Rod(lattice: lattice2)
    
    // Create 'housing'.
    housing = Housing()
    
    // Bring the parts into their start position.
    // TODO: Do this after, not before, creating the rigid bodies.
    alignParts()
    
    // Create 'rigidBodies'.
    createRigidBodies()
    
    // Create 'forceField'.
    createForceField()
  }
  
  mutating func alignParts() {
    for atomID in rod1.topology.atoms.indices {
      var atom = rod1.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      position += SIMD3(0.91, 0.85, -1.25)
      atom.position = position
      rod1.topology.atoms[atomID] = atom
    }
    for atomID in rod2.topology.atoms.indices {
      var atom = rod2.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      position = SIMD3(position.x, position.z, position.y)
      
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position += SIMD3(2.5 * latticeConstant, 0, 0)
      position += SIMD3(0.91, -1.25, 0.85)
      atom.position = position
      rod2.topology.atoms[atomID] = atom
    }
  }
  
  // Create rigid bodies, which store the positions, bonding topologies, and
  // bulk velocities (if any).
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

// MARK: - Simulation

// TODO: A function to synchronize the forcefield state with the rigid bodies.
// Call this function every time the state changes.

extension System {
  // Minimize the potential energy at zero temperature.
  mutating func minimize() {
    guard let forceField else {
      fatalError("Force field not initialized.")
    }
    
    forceField.positions = rigidBodies.flatMap(\.positions)
    print("Potential Energy:", forceField.energy.potential)
    forceField.minimize()
    print("Potential Energy:", forceField.energy.potential)
  }
  
  // Equilibriate the thermal potential energy.
  mutating func equilibriate(temperature: Double) {
    guard let forceField else {
      fatalError("Force field not initialized.")
    }
    
    // The equilibriation time is fixed, to simplify the function signature.
    let equilibriationTime: Double = 1
    for iterationID in 0...5 {
      var effectiveTemperature: Double
      if iterationID == 0 {
        effectiveTemperature = temperature * 2
      } else {
        effectiveTemperature = temperature
      }
      
      let thermalVelocities = createThermalVelocities(
        temperature: effectiveTemperature)
      forceField.velocities = thermalVelocities
      if iterationID == 0 {
        forceField.simulate(time: equilibriationTime / 2)
      } else {
        forceField.simulate(time: equilibriationTime / 10)
      }
      print("Potential Energy:", forceField.energy.potential)
    }
  }
  
  // TODO: Separate the functions for assigning thermal velocities and
  // overriding the bulk momenta.
  func createThermalVelocities(temperature: Double) -> [SIMD3<Float>] {
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
    
    let integrator = OpenMM_VerletIntegrator(stepSize: 0)
    let context = OpenMM_Context(system: system, integrator: integrator)
    context.positions = positions
    context.setVelocitiesToTemperature(temperature)
    
    let state = context.state(types: [.velocities])
    let velocitiesObject = state.velocities
    var velocities: [SIMD3<Float>] = []
    for atomID in 0..<velocitiesObject.size {
      let velocity64 = velocitiesObject[atomID]
      let velocity32 = SIMD3<Float>(velocity64)
      velocities.append(velocity32)
    }
    
    // Do not overwrite the current rigid bodies; just reference them to
    // zero out the bulk momenta.
    var velocityCursor: Int = .zero
    for rigidBodyID in rigidBodies.indices {
      let oldRigidBody = rigidBodies[rigidBodyID]
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.positions = oldRigidBody.positions
      rigidBodyDesc.parameters = oldRigidBody.parameters
      
      let rangeStart = velocityCursor
      let rangeEnd = velocityCursor + oldRigidBody.parameters.atoms.count
      velocityCursor += oldRigidBody.parameters.atoms.count
      
      var selectedVelocities = Array(velocities[rangeStart..<rangeEnd])
      rigidBodyDesc.velocities = selectedVelocities
      var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
      rigidBody.linearMomentum = .zero
      rigidBody.angularMomentum = .zero
      selectedVelocities = rigidBody.velocities
      velocities.replaceSubrange(
        rangeStart..<rangeEnd, with: selectedVelocities)
    }
    
    return velocities
  }

}
