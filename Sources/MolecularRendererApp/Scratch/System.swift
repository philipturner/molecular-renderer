//
//  System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/18/24.
//

import Foundation
import HDL
import MM4
import OpenMM

// A configuration for a system.
struct SystemDescriptor {
  // An HDL description of the knobs for each rod.
  var patternA: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
  var patternB: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
  var patternC: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
}

struct System {
  var housing: Housing
  var inputDriveWall: DriveWall
  var outputDriveWall: DriveWall
  var rodA: Rod
  var rodB: Rod
  var rodC: Rod
  
  init(descriptor: SystemDescriptor) {
    // Create 'housing'.
    housing = Housing()
    
    // Create 'inputDriveWall'.
    var driveWallDescriptor = DriveWallDescriptor()
    driveWallDescriptor.cellCount = 2
    inputDriveWall = DriveWall(descriptor: driveWallDescriptor)
    
    // Create 'outputDriveWall'.
    driveWallDescriptor.cellCount = 1
    outputDriveWall = DriveWall(descriptor: driveWallDescriptor)
    
    // Create 'rodA'.
    var rodDescriptor = RodDescriptor()
    rodDescriptor.length = 14
    rodDescriptor.pattern = descriptor.patternA
    rodA = Rod(descriptor: rodDescriptor)
    
    // Create 'rodB'.
    rodDescriptor.length = 14
    rodDescriptor.pattern = descriptor.patternB
    rodB = Rod(descriptor: rodDescriptor)
    
    // Create 'rodC'.
    rodDescriptor.length = 23
    rodDescriptor.pattern = descriptor.patternC
    rodC = Rod(descriptor: rodDescriptor)
    
    alignParts()
  }
  
  mutating func alignParts() {
    // Shift the housing down by ~2 cells, to match the extension in the Y
    // direction.
    for atomID in housing.topology.atoms.indices {
      var atom = housing.topology.atoms[atomID]
      var position = atom.position
      position += SIMD3(0, -4 * 0.357, 0)
      atom.position = position
      housing.topology.atoms[atomID] = atom
    }
    
    // Align the drive wall with the housing.
    for atomID in inputDriveWall.topology.atoms.indices {
      var atom = inputDriveWall.topology.atoms[atomID]
      var position = atom.position
      
      // Set Y to either 0 or -2.2, to visualize ends of the clock cycle.
      position += SIMD3(-1.7, -2.2, -0.1)
      position = SIMD3(position.z, position.y, position.x)
      atom.position = position
      inputDriveWall.topology.atoms[atomID] = atom
    }
    
    // Align the drive wall with the housing.
    for atomID in outputDriveWall.topology.atoms.indices {
      var atom = outputDriveWall.topology.atoms[atomID]
      var position = atom.position
      
      // Set Y to either 1 or -1.2, to visualize ends of the clock cycle.
      position += SIMD3(-1.7, -1.2, -0.1)
      atom.position = position
      outputDriveWall.topology.atoms[atomID] = atom
    }
    
    // Align the rod with the housing.
    for atomID in rodA.topology.atoms.indices {
      var atom = rodA.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      
      // Set Z to either 0 or -0.8, to visualize ends of the clock cycle.
      position += SIMD3(0.91, 0.85, 0)
      atom.position = position
      rodA.topology.atoms[atomID] = atom
    }
    
    // Align the rod with the housing.
    for atomID in rodB.topology.atoms.indices {
      var atom = rodB.topology.atoms[atomID]
      var position = atom.position
      position = SIMD3(position.z, position.y, position.x)
      
      // Set Z to either 0 or -0.8, to visualize ends of the clock cycle.
      position += SIMD3(0.91 + 6 * 0.357, 0.85, 0)
      atom.position = position
      rodB.topology.atoms[atomID] = atom
    }
    
    // Align the rod with the housing.
    for atomID in rodC.topology.atoms.indices {
      var atom = rodC.topology.atoms[atomID]
      var position = atom.position
      
      // Set X to either 0 or -0.8, to visualize ends of the clock cycle.
      position += SIMD3(0, 1.83, 0.91)
      atom.position = position
      rodC.topology.atoms[atomID] = atom
    }
  }
  
  mutating func passivate() {
    housing.passivate()
    inputDriveWall.passivate()
    outputDriveWall.passivate()
    rodA.passivate()
    rodB.passivate()
    rodC.passivate()
  }
}

extension System {
  func getTopologies() -> [Topology] {
    var topologies: [Topology] = []
    topologies.append(housing.topology)
    topologies.append(inputDriveWall.topology)
    topologies.append(outputDriveWall.topology)
    topologies.append(rodA.topology)
    topologies.append(rodB.topology)
    topologies.append(rodC.topology)
    return topologies
  }
  
  mutating func setTopologies(_ topologies: [Topology]) {
    guard topologies.count == 6 else {
      fatalError("Invalid topology count.")
    }
    housing.topology = topologies[0]
    inputDriveWall.topology = topologies[1]
    outputDriveWall.topology = topologies[2]
    rodA.topology = topologies[3]
    rodB.topology = topologies[4]
    rodC.topology = topologies[5]
  }
  
  mutating func minimizeSurfaces() {
    var topologies = getTopologies()
    
    var emptyParamsDesc = MM4ParametersDescriptor()
    emptyParamsDesc.atomicNumbers = []
    emptyParamsDesc.bonds = []
    var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
    
    for topologyID in topologies.indices {
      let topology = topologies[topologyID]
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      var partParameters = try! MM4Parameters(descriptor: paramsDesc)
      
      // Don't let the bulk atoms move during the minimization.
      for atomID in topology.atoms.indices {
        let centerType = partParameters.atoms.centerTypes[atomID]
        if centerType == .quaternary {
          partParameters.atoms.masses[atomID] = 0
        }
      }
      systemParameters.append(contentsOf: partParameters)
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.cutoffDistance = 1 // not simulating dynamics yet
    forceFieldDesc.parameters = systemParameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    
    var atoms = topologies.flatMap(\.atoms)
    forceField.positions = atoms.map(\.position)
    forceField.minimize()
    for atomID in atoms.indices {
      var atom = atoms[atomID]
      atom.position = forceField.positions[atomID]
      atoms[atomID] = atom
    }
    
    var atomCursor: Int = 0
    for topologyID in topologies.indices {
      var topology = topologies[topologyID]
      for atomID in topology.atoms.indices {
        let atom = atoms[atomCursor]
        topology.atoms[atomID] = atom
        atomCursor += 1
      }
      topologies[topologyID] = topology
    }
    
    setTopologies(topologies)
  }
}

extension System {
  func getAtomCounts() -> [Int] {
    var atomCounts: [Int] = []
    atomCounts.append(housing.topology.atoms.count)
    atomCounts.append(inputDriveWall.topology.atoms.count)
    atomCounts.append(outputDriveWall.topology.atoms.count)
    atomCounts.append(rodA.topology.atoms.count)
    atomCounts.append(rodB.topology.atoms.count)
    atomCounts.append(rodC.topology.atoms.count)
    return atomCounts
  }
  
  func getAtomVelocities() -> [[SIMD3<Float>]] {
    let atomCounts = getAtomCounts()
    func emptyVelocities(count: Int) -> [SIMD3<Float>] {
      var output: [SIMD3<Float>] = []
      for _ in 0..<count {
        output.append(.zero)
      }
      return output
    }
    
    var atomVelocities: [[SIMD3<Float>]] = []
    atomVelocities.append(
      housing.velocities ?? emptyVelocities(count: atomCounts[0]))
    atomVelocities.append(
      inputDriveWall.velocities ?? emptyVelocities(count: atomCounts[1]))
    atomVelocities.append(
      outputDriveWall.velocities ?? emptyVelocities(count: atomCounts[2]))
    atomVelocities.append(
      rodA.velocities ?? emptyVelocities(count: atomCounts[3]))
    atomVelocities.append(
      rodB.velocities ?? emptyVelocities(count: atomCounts[4]))
    atomVelocities.append(
      rodC.velocities ?? emptyVelocities(count: atomCounts[5]))
    return atomVelocities
  }
  
  mutating func setAtomVelocities(_ atomVelocities: [[SIMD3<Float>]]) {
    guard atomVelocities.count == 6 else {
      fatalError("Invalid topology count.")
    }
    housing.velocities = atomVelocities[0]
    inputDriveWall.velocities = atomVelocities[1]
    outputDriveWall.velocities = atomVelocities[2]
    rodA.velocities = atomVelocities[3]
    rodB.velocities = atomVelocities[4]
    rodC.velocities = atomVelocities[5]
  }
  
  // Create rigid bodies from the parts. Assigns parameters for bonded and
  // nonbonded forces.
  // - The parameters descriptor specifies which forces to assign parameters
  //   for.
  func createRigidBodies(
    parametersDescriptor: MM4ParametersDescriptor
  ) -> [MM4RigidBody] {
    let topologies = getTopologies()
    let atomVelocities = getAtomVelocities()
    
    var rigidBodies: [MM4RigidBody] = []
    for topologyID in topologies.indices {
      let topology = topologies[topologyID]
      
      var paramsDesc = parametersDescriptor
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      let parameters = try! MM4Parameters(descriptor: paramsDesc)
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = parameters
      rigidBodyDesc.positions = topology.atoms.map(\.position)
      rigidBodyDesc.velocities = atomVelocities[topologyID]
      let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      rigidBodies.append(rigidBody)
    }
    return rigidBodies
  }
  
  // Create random velocities, according to the Boltzmann distribution.
  func createRandomThermalVelocities() -> [[SIMD3<Float>]] {
    let topologies = getTopologies()
    let atoms = topologies.flatMap(\.atoms)
    let openmmSystem = OpenMM_System()
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      
      var mass: Double
      switch atom.atomicNumber {
      case 1: mass = 1.008
      case 6: mass = 12.011
      case 14: mass = 28.085
      default: fatalError("Element not recognized.")
      }
      openmmSystem.addParticle(mass: mass)
    }
    let openmmIntegrator = OpenMM_VerletIntegrator(stepSize: 0)
    let openmmContext = OpenMM_Context(
      system: openmmSystem, integrator: openmmIntegrator)
    let openmmPositions = OpenMM_Vec3Array(size: atoms.count)
    for atomID in atoms.indices {
      let atom = atoms[atomID]
      let position = SIMD3<Double>(atom.position)
      openmmPositions[atomID] = position
    }
    openmmContext.positions = openmmPositions
    openmmContext.setVelocitiesToTemperature(298)
    let openmmState = openmmContext.state(types: [.velocities])
    let openmmVelocities = openmmState.velocities
    
    let atomCounts = getAtomCounts()
    var atomCursor: Int = 0
    var atomVelocities: [[SIMD3<Float>]] = []
    for partID in atomCounts.indices {
      var velocities: [SIMD3<Float>] = []
      let atomCount = atomCounts[partID]
      for _ in 0..<atomCount {
        let velocityDouble = openmmVelocities[atomCursor]
        let velocitySingle = SIMD3<Float>(velocityDouble)
        velocities.append(velocitySingle)
        atomCursor += 1
      }
      atomVelocities.append(velocities)
    }
    return atomVelocities
  }
}
