// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test whether switches with sideways knobs work correctly. Test every
// possible permutation of touching knobs and approach directions.
//
// Then, test whether extremely long rods work correctly.
//
// Notes:
// - Save each test to 'rod-logic', in a distinct set of labeled files. Then,
//   overwrite the contents and proceed with the next test.
// - Run each setup with MD at room temperature.
func createGeometry() -> [Entity] {
  let system = System()
  
  // Create rigid bodies, which store the positions, bonding topologies, and
  // bulk velocities (if any).
  var rigidBodies: [MM4RigidBody] = []
  do {
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
    
    let rigidBodyRod1 = createRigidBody(topology: system.rod1.topology)
    let rigidBodyRod2 = createRigidBody(topology: system.rod2.topology)
    let rigidBodyHousing = createRigidBody(topology: system.housing.topology)
    rigidBodies.append(rigidBodyRod1)
    rigidBodies.append(rigidBodyRod2)
    rigidBodies.append(rigidBodyHousing)
  }
  
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
    return velocities
  }
  
  // Create a single 'MM4Parameters' object from the rigid bodies.
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  for rigidBody in rigidBodies {
    let partParameters = rigidBody.parameters
    systemParameters.append(contentsOf: partParameters)
  }
  
  // Create the forcefield, but don't set the bulk velocities yet.
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = systemParameters
  //
  // Note: OpenMM_VerletIntegrator doesn't conserve energy as well as the
  // custom integrator. Perhaps we need to set a custom kinetic energy
  // expression.
  forceFieldDesc.integrator = .multipleTimeStep
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rigidBodies.flatMap(\.positions)
  forceField.minimize()
  
  // Add the thermal velocities and equilibriate. Record the energy drift, and
  // the thermal kinetic/potential energy.
  var energyDrifts: [Double] = []
  for iterationID in 0..<10 {
    var temperature: Double = 298
    if iterationID == 0 {
      temperature *= 2
    }
    
    // Energy drifts for 200 fs simulations (6571 atoms):
    // timeStep=4.35 | RMS Drift: 25.381630655561978
    // timeStep=4.00 | RMS Drift: 29.350738873948234
    // timeStep=3.50 | RMS Drift: 21.598473661799222
    // timeStep=3.00 | RMS Drift: 9.9675571081211
    // timeStep=2.50 | RMS Drift: 8.666203282675804
    // timeStep=2.00 | RMS Drift: 5.578050111806885
    // timeStep=1.75 | RMS Drift: 2.6580977252759106
    // timeStep=1.50 | RMS Drift: 2.4210065942965167
    // timeStep=1.25 | RMS Drift: 1.1603037378127872
    // timeStep=1.00 | RMS Drift: 0.9260122244849645
    // timeStep=0.88 | RMS Drift: 0.7831310242435118
    // timeStep=0.75 | RMS Drift: 0.9983872489449445
    // timeStep=0.63 | RMS Drift: 0.44236257177910554
    // timeStep=0.50 | RMS Drift: 0.2611367900657507
    // timeStep=0.44 | RMS Drift: 0.3885328085591009
    // timeStep=0.38 | RMS Drift: 0.19615450735840045
    // timeStep=0.25 | RMS Drift: 0.22480208872323384
    //
    // Energy drifts for 10 ps simulations (6571 atoms):
    //
    let thermalVelocities = createThermalVelocities(temperature: temperature)
    forceField.velocities = thermalVelocities
    forceField.timeStep = 0.25e-3
    
    func fmt(_ number: Double) -> String {
      String(format: "%.1f", number) + " zJ"
    }
    
    let originalKinetic = forceField.energy.kinetic
    let originalPotential = forceField.energy.potential
    let originalTotal = forceField.energy.kinetic + forceField.energy.potential
    print()
    print("Original Energies:")
    print("- kinetic:  ", fmt(originalKinetic))
    print("- potential:", fmt(originalPotential))
    print("- total:    ", fmt(originalTotal))
    
    if iterationID == 0 {
      forceField.simulate(time: 0.040)
    } else {
      forceField.simulate(time: 0.200)
    }
    
    func diff(_ initial: Double, _ final: Double) -> String {
      let difference = final - initial
      let sign = (difference.sign == .plus) ? "+" : ""
      return "(" + sign + fmt(difference) + ")"
    }
    
    let finalKinetic = forceField.energy.kinetic
    let finalPotential = forceField.energy.potential
    let finalTotal = forceField.energy.kinetic + forceField.energy.potential
    print()
    print("Final Energies:")
    print("- kinetic:  ", fmt(finalKinetic), diff(originalKinetic, finalKinetic))
    print("- potential:", fmt(finalPotential), diff(originalPotential, finalPotential))
    print("- total:    ", fmt(finalTotal), diff(originalTotal, finalTotal))
    
    if iterationID > 0 {
      energyDrifts.append(finalTotal - originalTotal)
    }
  }
  
  
  print()
  let totalSquare = energyDrifts.reduce(0) { $0 + $1 * $1 }
  let totalRMS = totalSquare.squareRoot() / Double(energyDrifts.count)
  print("RMS Drift: \(totalRMS)")
  print("Atom Count:", systemParameters.atoms.count)
  
  exit(0)
  
  var atoms: [Entity] = []
  atoms += system.rod1.topology.atoms
  atoms += system.rod2.topology.atoms
  atoms += system.housing.topology.atoms
  for i in atoms.indices {
    atoms[i].position = forceField.positions[i]
  }
  return atoms
}
