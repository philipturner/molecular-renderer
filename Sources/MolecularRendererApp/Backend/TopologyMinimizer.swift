//
//  Minimize.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/28/23.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// A second prototype of MM4; a stopgap until the library is finally running.
// Once the new simulator is running, archive this in the hardware catalog ASAP.
//
// Objectives for the new simulator in light of this prototype:
// - Remove rigid body mechanics and MM4LevelOfTheory
// - Make each force optional -> MM4ForceFieldDescriptor
// - Make cutoff customizable
// - Make hydrogen reduction optional

struct TopologyMinimizerDescriptor {
  var platform: OpenMM_Platform?
  var rigidBodies: [MM4RigidBody]?
  var timeStep: Double = 0.002
  var topology: Topology?
}

struct TopologyMinimizer {
  var context: OpenMM_Context!
  var forces: [OpenMM_Force] = []
  var integrator: OpenMM_Integrator!
  var parameters: MM4Parameters
  var system: OpenMM_System!
  var timeStep: Double
  var topology: Topology
  
  init(_ topology: Topology) {
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.topology = topology
    self.init(descriptor: descriptor)
    self.topology = topology
  }
  
  init(descriptor: TopologyMinimizerDescriptor) {
    self.timeStep = descriptor.timeStep
    
    // When performing rigid body dynamics experiments with this API, make
    // sure each rigid body is initialized with HMR disabled.
    if let topology = descriptor.topology {
      // If both topology and rigid bodies are specified, this will initialize
      // to the topology without warning you that arguments are invalid.
      self.topology = topology
      
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      paramsDesc.hydrogenMassScale = 1
      paramsDesc.forces = [.stretch, .bend, .stretchBend, .nonbonded]
      self.parameters = try! MM4Parameters(descriptor: paramsDesc)
    } else if let rigidBodies = descriptor.rigidBodies {
      self.topology = Topology()
      
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = []
      paramsDesc.bonds = []
      self.parameters = try! MM4Parameters(descriptor: paramsDesc)
      
      for rigidBody in rigidBodies {
        parameters.append(contentsOf: rigidBody.parameters)
        var atoms: [Entity] = []
        for i in rigidBody.parameters.atoms.indices {
          let position = rigidBody.positions[i]
          let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[i]
          let storage = SIMD4(position, Float(atomicNumber))
          atoms.append(Entity(storage: storage))
        }
        topology.insert(atoms: atoms)
      }
      topology.insert(bonds: parameters.bonds.indices)
      
      
    } else {
      fatalError("Neither topology nor rigid bodies were specified.")
    }
    
    self.initializeStretchForce()
    self.initializeBendForce()
    self.initializeNonbondedForce()
    self.initializeSystem(platform: descriptor.platform)
    
    if let rigidBodies = descriptor.rigidBodies {
      var velocities: [SIMD3<Float>] = []
      for rigidBody in rigidBodies {
        velocities += rigidBody.velocities
      }
      setVelocities(velocities)
    }
  }
  
  func createForces() -> [SIMD3<Float>] {
    reportForces()
  }
  
  func createPotentialEnergy() -> Double {
    reportEnergy().potential
  }
  
  func createKineticEnergy() -> Double {
    reportEnergy().kinetic
  }
  
  func createVelocities() -> [SIMD3<Float>] {
    let dataTypes: OpenMM_State.DataType = [
      OpenMM_State.DataType.velocities
    ]
    let query = context.state(types: dataTypes)
    let velocities = query.velocities
    var output: [SIMD3<Float>] = []
    
    for i in parameters.atoms.indices {
      let modified = SIMD3<Float>(velocities[i])
      output.append(modified)
    }
    return output
  }
  
  // <s>
  // This takes O(n^2) time to export because it doesn't cache the data like
  // MM4ForceField does. Luckily, isn't the way forces are exported. It also
  // won't be used for time evolution in the rigid body dynamics experiment.
  // </s>
  //
  // This takes O(n) time because the positions are stored in the Topology. But,
  // it does not modify the velocities of the rigid body's atoms. Don't add
  // such exporting functionality until we start performing rigid body
  // dynamics simulations and comparing the bulk velocities to the MD
  // simulation trajectory.
//  func export(to rigidBody: inout MM4RigidBody, range: Range<Int>) {
//    // This function for fetching is O(n^2) right now.
//    let allVelocities = createVelocities()
//    
//    var positions: [SIMD3<Float>] = []
//    var velocities: [SIMD3<Float>] = []
//    for i in 0..<range.count {
//      let index = range.startIndex + i
//      let position = topology.atoms[index].position
//      let velocity = allVelocities[index]
//      positions.append(position)
//      velocities.append(velocity)
//    }
//    rigidBody.setPositions(positions)
//    rigidBody.setVelocities(velocities)
//  }
}

// MARK: - Mutating Functions

extension TopologyMinimizer {
  
  // This simple API provides no control over velocities in the simulator; only
  // control over positions.
  mutating func setPositions(_ positions: [SIMD3<Float>]) {
    precondition(
      positions.count == topology.atoms.count,
      "Positions array has incorrect size.")
    let array = OpenMM_Vec3Array(size: positions.count)
    for i in positions.indices {
      array[i] = SIMD3(positions[i])
      topology.atoms[i].position = positions[i]
    }
    context.positions = array
  }
  
  mutating func setVelocities(_ velocities: [SIMD3<Float>]) {
    precondition(
      velocities.count == topology.atoms.count,
      "Velocities array has incorrect size.")
    let array = OpenMM_Vec3Array(size: velocities.count)
    for i in velocities.indices {
      array[i] = SIMD3(velocities[i])
    }
    context.velocities = array
  }
  
  mutating func minimize() {
    // A minimizaton reporter doesn't report anything here.
    OpenMM_LocalEnergyMinimizer.minimize(context: context, tolerance: 10 * MM4KJPerMolPerZJ, reporter: nil)
    let minimizedPositions = reportPositions()
    for i in parameters.atoms.indices {
      topology.atoms[i].position = minimizedPositions[i]
    }
  }
  
  // WARNING: Sort the topology before simulating. This will speed up
  // simulation time. In order to do this, sort before you create the
  // TopologyMinimizer object.
  mutating func simulate(time: Double) {
    let numSteps = Double((time / timeStep).rounded(.down))
    if numSteps > 0 {
      integrator.stepSize = timeStep
      integrator.step(Int(exactly: numSteps)!)
    }
    let remaining = time - numSteps * timeStep
    if remaining > 1e-6 {
      integrator.stepSize = remaining
      integrator.step(1)
    } else {
    }
    let simulatedPositions = reportPositions()
    for i in parameters.atoms.indices {
      topology.atoms[i].position = simulatedPositions[i]
    }
  }
}
  
extension TopologyMinimizer {
  private func reportEnergy() -> (
    potential: Double,
    kinetic: Double
  ) {
    let dataTypes: OpenMM_State.DataType = [
      OpenMM_State.DataType.energy
    ]
    let query = context.state(types: dataTypes)
    
    let potential = query.potentialEnergy * MM4ZJPerKJPerMol
    let kinetic = query.kineticEnergy * MM4ZJPerKJPerMol
    return (potential, kinetic)
  }
  
  private func reportPositions() -> [SIMD3<Float>] {
    let dataTypes: OpenMM_State.DataType = [
      OpenMM_State.DataType.positions
    ]
    let query = context.state(types: dataTypes)
    let positions = query.positions
    var output: [SIMD3<Float>] = []
    
    for i in parameters.atoms.indices {
      let modified = SIMD3<Float>(positions[i])
      output.append(modified)
    }
    return output
  }
  
  private func reportForces() -> [SIMD3<Float>] {
    let dataTypes: OpenMM_State.DataType = [
      OpenMM_State.DataType.forces
    ]
    let query = context.state(types: dataTypes)
    let forces = query.forces
    var output: [SIMD3<Float>] = []
    
    for i in parameters.atoms.indices {
      // Units: kJ/mol/nm -> pN
      var modified = SIMD3<Float>(forces[i])
      modified *= Float(MM4ZJPerKJPerMol)
      output.append(modified)
    }
    return output
  }
}

// MARK: - Initialization

extension TopologyMinimizer {
  
  private mutating func initializeSystem(platform: OpenMM_Platform?) {
    self.system = OpenMM_System()
    let arrayP = OpenMM_Vec3Array(size: parameters.atoms.count)
    let arrayV = OpenMM_Vec3Array(size: parameters.atoms.count)
    for atomID in parameters.atoms.indices {
      // Units: yg -> amu
      var mass = parameters.atoms.masses[atomID]
      mass *= Float(MM4AmuPerYg)
      system.addParticle(mass: Double(mass))
      arrayP[atomID] = SIMD3<Double>(topology.atoms[atomID].position)
      arrayV[atomID] = SIMD3<Double>.zero
    }
    
    for force in forces {
      force.forceGroup = 1
      force.transfer()
      system.addForce(force)
    }
    
    // It doesn't matter what step size the integrator is initialized at.
    self.integrator = OpenMM_VerletIntegrator(stepSize: 0)
    
    
//    let integrator = OpenMM_CustomIntegrator(stepSize: 0)
//    integrator.addUpdateContextState()
//    integrator.addComputePerDof(variable: "v", expression: """
//      v + 0.5 * dt * f1 / m
//      """)
//    integrator.addComputePerDof(variable: "v", expression: """
//      v + 0.25 * dt * f2 / m
//      """)
//    integrator.addComputePerDof(variable: "x", expression: """
//      x + 0.5 * dt * v
//      """)
//    integrator.addConstrainPositions()
//    
//    integrator.addComputePerDof(variable: "v", expression: """
//      v + 0.5 * dt * f2 / m
//      """)
//    integrator.addComputePerDof(variable: "x", expression: """
//      x + 0.5 * dt * v
//      """)
//    integrator.addConstrainPositions()
//    integrator.addComputePerDof(variable: "v", expression: """
//      v + 0.25 * dt * f2 / m
//      """)
//    integrator.addComputePerDof(variable: "v", expression: """
//      v + 0.5 * dt * f1 / m
//      """)
//    
//    
//    self.integrator = integrator
    
    if let platform {
      self.context = OpenMM_Context(
        system: system, integrator: integrator, platform: platform)
    } else {
      self.context = OpenMM_Context(system: system, integrator: integrator)
    }
    context.positions = arrayP
    context.velocities = arrayV
  }
  
  private mutating func initializeStretchForce() {
    let stretchForce = OpenMM_CustomBondForce(energy: """
      potentialWellDepth * ((
        1 - exp(-beta * (r - equilibriumLength))
      )^2);
      """)
    stretchForce.addPerBondParameter(name: "potentialWellDepth")
    stretchForce.addPerBondParameter(name: "beta")
    stretchForce.addPerBondParameter(name: "equilibriumLength")
    
    let array = OpenMM_DoubleArray(size: 3)
    let bonds = parameters.bonds
    for bondID in bonds.indices.indices {
      // Pre-multiply constants in formulas as much as possible. For example,
      // the "beta" constant for bond stretch is multiplied by
      // 'OpenMM_AngstromsPerNm'. This reduces the amount of computation during
      // force execution.
      let bond = bonds.indices[bondID]
      let parameters = bonds.parameters[bondID]
      guard parameters.potentialWellDepth != 0 else {
        continue
      }
      
      // Units: millidyne-angstrom -> kJ/mol
      var potentialWellDepth = Double(parameters.potentialWellDepth)
      potentialWellDepth *= MM4KJPerMolPerAJ
      
      // Units: angstrom^-1 -> nm^-1
      var beta = Double(
        parameters.stretchingStiffness / (2 * parameters.potentialWellDepth)
      ).squareRoot()
      beta /= OpenMM_NmPerAngstrom
      
      // Units: angstrom -> nm
      var equilibriumLength = Double(parameters.equilibriumLength)
      equilibriumLength *= OpenMM_NmPerAngstrom
      
      let particles = SIMD2<Int>(truncatingIfNeeded: bond)
      array[0] = potentialWellDepth
      array[1] = beta
      array[2] = equilibriumLength
      stretchForce.addBond(particles: particles, parameters: array)
    }
    
    self.forces.append(stretchForce)
  }
  
  mutating func initializeBendForce() {
    // This could probably include the sextic Taylor expansion and be just fine.
    // We're just playing it safe and simple; there are more important issues.
    // There are also accuracy issues with this simulator's nonbonded force,
    // which doesn't include hydrogen reductions.
//    let bendForce = OpenMM_CustomCompoundBondForce(numParticles: 3, energy: """
//      bend;
//      bend = bendingStiffness * deltaTheta^2;
//      deltaTheta = angle(p1, p2, p3) - equilibriumAngle;
//      """)
    
    let correction = 180 / Float.pi
    // let bendingStiffness = /*71.94*/ 1.00 * bendingStiffness
    let cubicTerm = 0.014 * correction
    let quarticTerm = 5.6e-5 * pow(correction, 2)
    let quinticTerm = 7.0e-7 * pow(correction, 3)
    let sexticTerm = 2.2e-8 * pow(correction, 4)
    let bendForce = OpenMM_CustomCompoundBondForce(numParticles: 3, energy: """
    bend + stretchBend;
    bend = bendingStiffness * deltaTheta^2 * (
      1
      - \(cubicTerm) * deltaTheta
      + \(quarticTerm) * deltaTheta^2
      - \(quinticTerm) * deltaTheta^3
      + \(sexticTerm) * deltaTheta^4
    );
    stretchBend = stretchBendStiffness * deltaTheta * (
      deltaLengthLeft + deltaLengthRight
    );
    
    deltaTheta = angle(p1, p2, p3) - equilibriumAngle;
    deltaLengthLeft = distance(p1, p2) - equilibriumLengthLeft;
    deltaLengthRight = distance(p3, p2) - equilibriumLengthRight;
    """)
    bendForce.addPerBondParameter(name: "bendingStiffness")
    bendForce.addPerBondParameter(name: "equilibriumAngle")
    bendForce.addPerBondParameter(name: "stretchBendStiffness")
    bendForce.addPerBondParameter(name: "equilibriumLengthLeft")
    bendForce.addPerBondParameter(name: "equilibriumLengthRight")
    
    let particles = OpenMM_IntArray(size: 3)
    let array = OpenMM_DoubleArray(size: 5)
    let bonds = parameters.bonds
    let angles = parameters.angles
    for angleID in angles.indices.indices {
      let angle = angles.indices[angleID]
      let parameters = angles.parameters[angleID]
      guard parameters.bendingStiffness != 0 else {
        continue
      }
      
      // Units: millidyne-angstrom/rad^2 -> kJ/mol/rad^2
      //
      // WARNING: 143 needs to be divided by 2 before it becomes 71.94.
      var bendingStiffness = Double(parameters.bendingStiffness)
      bendingStiffness *= MM4KJPerMolPerAJ
      bendingStiffness /= 2
      
      // Units: degree -> rad
      var equilibriumAngle = Double(parameters.equilibriumAngle)
      equilibriumAngle *= OpenMM_RadiansPerDegree
      
      // Units: millidyne-angstrom/rad^2 -> kJ/mol/rad^2
      //
      // This part does not need to be divided by 2; it was never divided by
      // 2 in the first place (2.5118 was used instead of 1.2559).
      var stretchBendStiffness = Double(parameters.stretchBendStiffness)
      stretchBendStiffness *= MM4KJPerMolPerAJ
      
      // Units: angstrom -> nm
      @inline(__always)
      func sortBond<T>(_ codes: SIMD2<T>) -> SIMD2<T>
      where T: FixedWidthInteger {
        if codes[0] > codes[1] {
          return SIMD2(codes[1], codes[0])
        } else {
          return codes
        }
      }
      let bondLeft = sortBond(SIMD2(angle[0], angle[1]))
      let bondRight = sortBond(SIMD2(angle[1], angle[2]))
      
      @inline(__always)
      func createLength(_ bond: SIMD2<UInt32>) -> Double {
        guard let bondID = bonds.map[bond] else {
          fatalError("Invalid bond.")
        }
        let parameters = bonds.parameters[Int(bondID)]
        var equilibriumLength = Double(parameters.equilibriumLength)
        equilibriumLength *= OpenMM_NmPerAngstrom
        return equilibriumLength
      }
      
      let reorderedAngle = SIMD3<Int>(truncatingIfNeeded: angle)
      for lane in 0..<3 {
        particles[lane] = reorderedAngle[lane]
      }
      array[0] = bendingStiffness
      array[1] = equilibriumAngle
      array[2] = stretchBendStiffness
      array[3] = createLength(bondLeft)
      array[4] = createLength(bondRight)
      bendForce.addBond(particles: particles, parameters: array)
    }
    
    self.forces.append(bendForce)
  }
  
  private mutating func initializeNonbondedForce() {
    func createExceptions(force: OpenMM_CustomNonbondedForce) {
      for bond in parameters.bonds.indices {
        let reordered = SIMD2<Int>(truncatingIfNeeded: bond)
        force.addExclusion(particles: reordered)
      }
      for exception in parameters.nonbondedExceptions13 {
        let reordered = SIMD2<Int>(truncatingIfNeeded: exception)
        force.addExclusion(particles: reordered)
      }
    }
    
    var cutoff: Double {
      // Since germanium will rarely be used, use the cutoff for silicon. The
      // slightly greater sigma for carbon allows greater accuracy in vdW forces
      // for bulk diamond. 1.020 nm also accomodates charge-charge interactions.
//      let siliconRadius = 2.290 * OpenMM_NmPerAngstrom
//      return siliconRadius * 2.5 * OpenMM_SigmaPerVdwRadius
      return 1.0
    }
    
    let nonbondedForce = OpenMM_CustomNonbondedForce(energy: """
      epsilon * (
        -2.25 * (min(2, radius / r))^6 +
        1.84e5 * exp(-12.00 * (r / radius))
      );
      epsilon = select(isHydrogenBond, heteroatomEpsilon, hydrogenEpsilon);
      radius = select(isHydrogenBond, heteroatomRadius, hydrogenRadius);
      
      isHydrogenBond = step(hydrogenEpsilon1 * hydrogenEpsilon2);
      heteroatomEpsilon = sqrt(epsilon1 * epsilon2);
      hydrogenEpsilon = max(hydrogenEpsilon1, hydrogenEpsilon2);
      heteroatomRadius = radius1 + radius2;
      hydrogenRadius = max(hydrogenRadius1, hydrogenRadius2);
      """)
    nonbondedForce.addPerParticleParameter(name: "epsilon")
    nonbondedForce.addPerParticleParameter(name: "hydrogenEpsilon")
    nonbondedForce.addPerParticleParameter(name: "radius")
    nonbondedForce.addPerParticleParameter(name: "hydrogenRadius")
    
    nonbondedForce.nonbondedMethod = .cutoffNonPeriodic
    nonbondedForce.useSwitchingFunction = true
    nonbondedForce.cutoffDistance = cutoff
    nonbondedForce.switchingDistance = cutoff * pow(1.0 / 3, 1.0 / 6)
    
    let array = OpenMM_DoubleArray(size: 4)
    let atoms = parameters.atoms
    for atomID in parameters.atoms.indices {
      let parameters = atoms.parameters[Int(atomID)]
      
      // Units: kcal/mol -> kJ/mol
      let (epsilon, hydrogenEpsilon) = parameters.epsilon
      array[0] = Double(epsilon) * OpenMM_KJPerKcal
      array[1] = Double(hydrogenEpsilon) * OpenMM_KJPerKcal
      
      // Units: angstrom -> nm
      let (radius, hydrogenRadius) = parameters.radius
      array[2] = Double(radius) * OpenMM_NmPerAngstrom
      array[3] = Double(hydrogenRadius) * OpenMM_NmPerAngstrom
      nonbondedForce.addParticle(parameters: array)
    }
    createExceptions(force: nonbondedForce)
    
    self.forces.append(nonbondedForce)
  }
}
