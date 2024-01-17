//
//  ElasticModuli_DiamondAnvil.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 1/17/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  // This code is getting very unwieldy and should be rewritten after the
  // diamond anvil experiment is done. Rewrite it using organized data
  // structures, extensible to different jigs and elastic moduli.
  
  // MARK: - Geometry Generation
  
  let material: MaterialType = .elemental(.carbon)
  
  func createRigidBody(_ lattice: Lattice<Cubic>, anchor: Bool) -> MM4RigidBody {
    var topology = Topology()
    topology.insert(atoms: lattice.atoms)
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = material
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    if anchor {
      for i in parameters.atoms.indices {
        if parameters.atoms.centerTypes[i] == .quaternary {
          parameters.atoms.masses[i] = 0
        }
      }
    }
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    return try! MM4RigidBody(descriptor: rigidBodyDesc)
  }
  
  let latticeSize: Int = 10
  let latticeJig = Lattice<Cubic> { h, k, l in
    Bounds { Float(latticeSize + 3) * (h + k + l) }
    Material { material }
    
    Volume {
      Origin { 1 * (h + k + l) }
      Concave {
        Plane { h }
        Plane { k }
        Plane { l }
        Origin { 0.25 * (h + k + l) }
        Plane { h + k }
        Plane { h + l }
        Plane { k + l }
      }
      Replace { .empty }
    }
  }
  
  var jig = createRigidBody(latticeJig, anchor: true)
  
  let latticeSpecimen = Lattice<Cubic> { h, k, l in
    Bounds { Float(latticeSize) * (h + k + l) }
    Material { material }
  }
  
  var specimen = createRigidBody(latticeSpecimen, anchor: false)
  
  // MARK: - Force Generation
  
  var handlePositions: Set<Int> = []
  do {
    var maxCoords: SIMD3<Float> = .init(repeating: -.greatestFiniteMagnitude)
    for (position, atomicNumber) in zip(
      specimen.positions, specimen.parameters.atoms.atomicNumbers
    ) {
      if atomicNumber != 1 {
        maxCoords.replace(with: position, where: position .> maxCoords)
      }
    }
    
    for (atomID, position) in specimen.positions.enumerated() {
      guard specimen.parameters.atoms.atomicNumbers[atomID] != 1 else {
        continue
      }
      if any(position .>= maxCoords - 1e-3) {
        handlePositions.insert(atomID)
      }
    }
  }
  
  var specimenForces = [SIMD3<Float>](
    repeating: .zero, count: specimen.parameters.atoms.count)
  for (atomID, position) in specimen.positions.enumerated() {
    let atomicNumber = specimen.parameters.atoms.atomicNumbers[atomID]
    if handlePositions.contains(atomID) {
      var maxAxis = -1
      var maxDirection: Float = -.greatestFiniteMagnitude
      for lane in 0..<3 {
        if position[lane] > maxDirection {
          maxAxis = lane
          maxDirection = position[lane]
        }
      }
      var force: SIMD3<Float> = .zero
      force[maxAxis] = 1 // 1 pN/atom ≈ 16 MPa
      specimenForces[atomID] = force
    }
  }
  
  let latticeConstant = Constant(.square) { material }
  var perFaceArea = latticeConstant * Float(latticeSize)
  perFaceArea *= perFaceArea
  let totalForces = specimenForces.reduce(SIMD3.zero, +)
  print("- total forces (pN):", totalForces)
  
  let totalPressures = totalForces / perFaceArea
  print("- total pressures (MPa):", totalPressures)
  
  // MARK: - Scene Setup
  
  specimen.centerOfMass += SIMD3<Double>(
    2.5 * latticeConstant * SIMD3(repeating: 1))
  
  var parameters = jig.parameters
  parameters.append(contentsOf: specimen.parameters)
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = jig.positions + specimen.positions
  forceField.minimize()
  
  var cursor = 0
  func update(_ rigidBody: inout MM4RigidBody) {
    var descriptor = MM4RigidBodyDescriptor()
    descriptor.parameters = rigidBody.parameters
    descriptor.positions = []
    for _ in rigidBody.parameters.atoms.indices {
      descriptor.positions!.append(forceField.positions[cursor])
      cursor += 1
    }
    rigidBody = try! MM4RigidBody(descriptor: descriptor)
  }
  update(&jig)
  update(&specimen)
  
  var output: [[Entity]] = []
  for trialID in 0..<3 {
    var minimumPotentialEnergy: Double = .greatestFiniteMagnitude
    specimen.linearMomentum = .zero
    specimen.angularMomentum = .zero
    
    for frameID in 0..<240 {
      let potentialEnergy = forceField.energy.potential
      let timeStep: Double = 0.040
      if frameID % 10 == 0 {
        print("frame=\(frameID), time=\(String(format: "%.3f", timeStep * Double(frameID))), potential=\(String(format: "%.3f", Double(potentialEnergy)))")
      }
      
      if potentialEnergy >= minimumPotentialEnergy {
        print("exit_frame=\(frameID)")
        
        // Account for the deformations from surface-surface interactions, which
        // were not modeled by rigid body mechanics.
        if trialID == 2 {
          print("exit_potential=\(forceField.energy.potential)")
          forceField.minimize()
          print("exit_potential=\(forceField.energy.potential)")
        }
      } else {
        // Perform the last trial with MD to maximize accuracy.
        if trialID == 2 {
          forceField.simulate(time: timeStep)
        } else {
          let forces = forceField.forces
          let range = jig.positions.count..<parameters.atoms.count
          specimen.forces = Array(forces[range])
          specimen.linearMomentum += timeStep * specimen.netForce!
          specimen.angularMomentum += timeStep * specimen.netTorque!
          
          let velocity = specimen.linearMomentum / specimen.mass
          let angularVelocity = specimen.angularMomentum / specimen.momentOfInertia
          let angularSpeed = (angularVelocity * angularVelocity).sum().squareRoot()
          specimen.centerOfMass += timeStep * velocity
          specimen.rotate(angle: timeStep * angularSpeed)
          
          forceField.positions = jig.positions + specimen.positions
        }
      }
      
      var frame: [Entity] = []
      for i in parameters.atoms.indices {
        let position = forceField.positions[i]
        let atomicNumber = parameters.atoms.atomicNumbers[i]
        let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
        frame.append(entity)
      }
//      output.append(frame)
      
      if potentialEnergy >= minimumPotentialEnergy {
        break
      }
      minimumPotentialEnergy = potentialEnergy
    }
  }
  
  // MARK: - Force Application
  
  print()
  for frameID in 0..<120 {
    let forceMultiplier = 100 * Float(frameID)
    let timeStep: Double = 0.100
    if frameID % 10 == 0 {
      let atomForce = 1 * forceMultiplier
      let pressure = Float(totalPressures[0]) * forceMultiplier
      print("frame=\(frameID), force=\(String(format: "%.0f", atomForce)) pN/atom, pressure=\(String(format: "%.0f", pressure)) MPa")
    }
    
    var externalForces = [SIMD3<Float>](
      repeating: .zero, count: jig.parameters.atoms.count)
    externalForces += specimenForces
    for i in externalForces.indices {
      // Make the force point inward.
      externalForces[i] *= -forceMultiplier
    }
    forceField.externalForces = externalForces
    
    let velocities = [SIMD3<Float>](
      repeating: .zero, count: externalForces.count)
    forceField.velocities = velocities
    
    // Do the minimizaton and MD simulation approaches give different results?
//    forceField.minimize(maxIterations: 30)
    forceField.simulate(time: timeStep)
    
    var frame: [Entity] = []
    for i in parameters.atoms.indices {
      let position = forceField.positions[i]
      let atomicNumber = parameters.atoms.atomicNumbers[i]
      let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
      frame.append(entity)
    }
    
    if forceField.positions.allSatisfy({ all($0 .< 10)  && all($0 .> -1) }) {
      if frameID % 10 == 0 {
        output.append(frame)
        output.append(frame)
        output.append(frame)
      } else {
        output.append(output.last!)
        output.append(output.last!)
        output.append(output.last!)
      }
      continue
    } else {
      print("Failed after \(frameID) frames.")
      output.append(frame)
      output.append(frame)
      output.append(frame)
      break
    }
  }
  
  return output
}
