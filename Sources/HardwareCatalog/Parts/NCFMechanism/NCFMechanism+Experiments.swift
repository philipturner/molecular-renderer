//
//  NCFMechanism+Experiments.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/5/24.
//

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

extension NCFMechanism {
  static func createEntities(_ rigidBodies: [MM4RigidBody]) -> [Entity] {
    var output: [Entity] = []
    for rigidBody in rigidBodies {
      for i in rigidBody.parameters.atoms.indices {
        let position = rigidBody.positions[i]
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[i]
        let storage = SIMD4(position, Float(atomicNumber))
        output.append(Entity(storage: storage))
      }
    }
    return output
  }
}

extension NCFMechanism {
  @discardableResult
  static func simulationExperiment1() -> NCFMechanism {
    var mechanism = NCFMechanism(partCount: 2)
    
    print("before minimization:")
    var centersOfMass: [SIMD3<Float>] = []
    for i in mechanism.parts.indices {
      let centerOfMass = mechanism.parts[i].rigidBody.centerOfMass
      centersOfMass.append(centerOfMass)
      print("- part \(i) center of mass:", centerOfMass)
    }
    
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)

    var minimizer = TopologyMinimizer(descriptor: descriptor)
    minimizer.minimize()
    
    print("after minimization:")
    for i in mechanism.parts.indices {
      let range = mechanism.atomRange(partID: i)
      minimizer.export(to: &mechanism.parts[i].rigidBody, range: range)
      
      let centerOfMass = mechanism.parts[i].rigidBody.centerOfMass
      let delta = centerOfMass - centersOfMass[i]
      print("- part \(i) center of mass delta:", delta)
    }
    
    /*
     // Results of minimization with all forces activated:
     - part 0 center of mass delta: SIMD3<Float>(2.3841858e-05, -0.000230968, -5.7041645e-05)
     - part 1 center of mass delta: SIMD3<Float>(-7.677078e-05, -0.00022423267, 5.7518482e-05)
     
     // With only nonbonded force (the atoms will explode):
     - part 0 center of mass delta: SIMD3<Float>(0.0017161369, -0.0022693276, 0.011400461)
     - part 1 center of mass delta: SIMD3<Float>(-0.0023555756, -0.0018498898, -0.011299193)
     */
    
    return mechanism
  }
  
  // Report the force on a few atoms, as well as the net force on the entire
  // rigid body, using just nonbonded forces. Do this for a single part in
  // isolation, then a system of two parts.
  static func simulationExperiment2() {
    for partCount in [1, 2] {
      print("system with part count \(partCount):")
      var descriptor = TopologyMinimizerDescriptor()
      var mechanism = NCFMechanism(partCount: partCount)
      descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
      var minimizer = TopologyMinimizer(descriptor: descriptor)
      
      func reportForce() {
        let forces = minimizer.createForces()
        for i in mechanism.parts.indices {
          let range = mechanism.atomRange(partID: i)
          let forceSlice = Array(forces[range])
          print("  - rigid body \(i):")
          
          let netForce = forceSlice.reduce(SIMD3.zero, +)
          print("    - net force: \(netForce)")
          for j in 0..<5 {
            print("    - force on atom \(j): \(forceSlice[j])")
          }
        }
      }
      print("- all forces active:")
      reportForce()
      
      mechanism = NCFMechanism(
        partCount: partCount, forces: [.bend, .stretch])
      descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
      minimizer = TopologyMinimizer(descriptor: descriptor)
      print("- only bonded force active:")
      reportForce()
      
      mechanism = NCFMechanism(
        partCount: partCount, forces: [.nonbonded])
      descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
      minimizer = TopologyMinimizer(descriptor: descriptor)
      print("- only nonbonded force active:")
      reportForce()
    }
    
    /*
     // Results of experiment:
     system with part count 1:
     - all forces active:
       - rigid body 0:
         - net force: SIMD3<Float>(0.00012207031, 0.0056152344, 0.0017852783)
         - force on atom 0: SIMD3<Float>(-1921.6613, -1108.0686, -829.8974)
         - force on atom 1: SIMD3<Float>(-33.98469, -304.99826, -2248.3845)
         - force on atom 2: SIMD3<Float>(-35.140472, -2253.4448, -214.03224)
         - force on atom 3: SIMD3<Float>(-137.59875, 3071.9028, 1741.6849)
         - force on atom 4: SIMD3<Float>(-277.87555, 118.03337, -2251.45)
     - only bonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(-0.00024414062, 0.022338867, -0.0014648438)
         - force on atom 0: SIMD3<Float>(-1805.7195, -1042.5332, -737.1822)
         - force on atom 1: SIMD3<Float>(0.0, -155.90253, -2177.1855)
         - force on atom 2: SIMD3<Float>(0.0, -2104.634, 578.74084)
         - force on atom 3: SIMD3<Float>(-66.82612, 3168.6438, 2240.5735)
         - force on atom 4: SIMD3<Float>(-135.01497, 77.95102, -2177.1855)
     - only nonbonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(-0.00045776367, 0.014312744, 0.001953125)
         - force on atom 0: SIMD3<Float>(-115.94173, -65.53532, -92.71524)
         - force on atom 1: SIMD3<Float>(-33.98469, -149.09575, -71.198875)
         - force on atom 2: SIMD3<Float>(-35.140472, -148.81055, -792.7731)
         - force on atom 3: SIMD3<Float>(-70.77264, -96.74094, -498.88855)
         - force on atom 4: SIMD3<Float>(-142.86061, 40.082355, -74.264244)
     system with part count 2:
     - all forces active:
       - rigid body 0:
         - net force: SIMD3<Float>(482.71753, -34.40857, 2940.4807)
         - force on atom 0: SIMD3<Float>(-1921.6278, -1108.0612, -829.85754)
         - force on atom 1: SIMD3<Float>(-33.957573, -304.98904, -2248.3293)
         - force on atom 2: SIMD3<Float>(-35.070515, -2253.4067, -213.92505)
         - force on atom 3: SIMD3<Float>(-137.42212, 3071.9722, 1741.9692)
         - force on atom 4: SIMD3<Float>(-277.85794, 118.034615, -2251.4211)
       - rigid body 1:
         - net force: SIMD3<Float>(-482.71582, 34.424805, -2940.481)
         - force on atom 0: SIMD3<Float>(-1921.6202, -1106.5763, -836.877)
         - force on atom 1: SIMD3<Float>(-36.39625, -300.24835, -2205.652)
         - force on atom 2: SIMD3<Float>(-35.51847, -2251.9878, -217.73863)
         - force on atom 3: SIMD3<Float>(-139.04573, 3076.796, 1726.1029)
         - force on atom 4: SIMD3<Float>(-278.9405, 119.539215, -2214.6367)
     - only bonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(-0.00024414062, 0.022338867, -0.0014648438)
         - force on atom 0: SIMD3<Float>(-1805.7195, -1042.5332, -737.1822)
         - force on atom 1: SIMD3<Float>(0.0, -155.90253, -2177.1855)
         - force on atom 2: SIMD3<Float>(0.0, -2104.634, 578.74084)
         - force on atom 3: SIMD3<Float>(-66.82612, 3168.6438, 2240.5735)
         - force on atom 4: SIMD3<Float>(-135.01497, 77.95102, -2177.1855)
       - rigid body 1:
         - net force: SIMD3<Float>(-0.007446289, 0.0052490234, -0.0012817383)
         - force on atom 0: SIMD3<Float>(-1805.7158, -1042.531, -737.1823)
         - force on atom 1: SIMD3<Float>(-0.0005402844, -155.90225, -2177.1855)
         - force on atom 2: SIMD3<Float>(-0.0005403153, -2104.6375, 578.74365)
         - force on atom 3: SIMD3<Float>(-66.8088, 3168.644, 2240.562)
         - force on atom 4: SIMD3<Float>(-135.01465, 77.95073, -2177.1855)
     - only nonbonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(482.7202, -34.416443, 2940.4883)
         - force on atom 0: SIMD3<Float>(-115.9084, -65.52787, -92.675354)
         - force on atom 1: SIMD3<Float>(-33.957573, -149.08653, -71.1438)
         - force on atom 2: SIMD3<Float>(-35.070515, -148.7725, -792.6659)
         - force on atom 3: SIMD3<Float>(-70.596, -96.67168, -498.6041)
         - force on atom 4: SIMD3<Float>(-142.84297, 40.08359, -74.23554)
       - rigid body 1:
         - net force: SIMD3<Float>(-482.71893, 34.428284, -2940.4844)
         - force on atom 0: SIMD3<Float>(-115.90433, -64.045235, -99.69464)
         - force on atom 1: SIMD3<Float>(-36.39571, -144.34608, -28.466478)
         - force on atom 2: SIMD3<Float>(-35.51793, -147.35037, -796.4823)
         - force on atom 3: SIMD3<Float>(-72.23694, -91.84812, -514.4591)
         - force on atom 4: SIMD3<Float>(-143.92584, 41.588486, -37.45119)
     */
  }
  
  // Compute the net force and torque on each rigid body in the 2-part system.
  // Also, query the linear velocity and angular velocity. They should be
  // either zero or NAN.
  // - linear velocity/acceleration, force, mass
  // - angular velocity/acceleration, torque, moment of inertia
  static func simulationExperiment3() {
    let mechanism = NCFMechanism(partCount: 2, forces: [.nonbonded])
    
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
    let minimizer = TopologyMinimizer(descriptor: descriptor)
    
    let systemForces = minimizer.createForces()
    mechanism.reportState(forces: systemForces)
    
    /*
     // Results of experiment:
     system state, summarized by bulk properties:
     - rigid body 0:
       - mass: 18868.363
       - center of mass: 4.029469 0.8710828 0.12871301
       - moment of inertia: 4049.4663 -782.0105 -7.9631805e-05
                            -782.0105 106424.83 -6.2584877e-06
                            -7.9631805e-05 -6.2584877e-06 109983.74

       - linear velocity: 0.0 0.0 0.0
       - linear acceleration: 0.025583362 -0.0018239636 0.15584198
       - force: 482.71616 -34.415207 2940.4832

       - angular velocity: 0.0 | nan nan nan
       - angular acceleration: 0.035587516 | 0.99176 -0.12637188 0.021026526
       - torque: 533.364 | 0.274559 -0.94910926 0.15430143
     - rigid body 1:
       - mass: 18868.363
       - center of mass: 4.529469 0.8710828 0.84871304
       - moment of inertia: 4049.4663 -782.0105 -5.1021576e-05
                            -782.0105 106424.83 -2.9206276e-06
                            -5.1021576e-05 -2.9206276e-06 109983.74

       - linear velocity: 0.0 0.0 0.0
       - linear acceleration: -0.025583318 0.001824234 -0.15584189
       - force: -482.71533 34.42031 -2940.4812

       - angular velocity: 0.0 | nan nan nan
       - angular acceleration: 0.03179502 | -0.9814885 -0.18939526 -0.02845629
       - torque: 636.1889 | -0.19123301 -0.9690016 -0.15641549
     */
  }
}

extension NCFMechanism {
  // Run a few iterations of Verlet integration, then export the results to
  // an array of animation frames
  @discardableResult
  static func simulationExperiment4() -> [[Entity]] {
    let rigidBodyDynamics = true
    
    var mechanism = NCFMechanism(
      partCount: 40, forces:
        rigidBodyDynamics ? [
          .nonbonded
        ] : [
          .bend, .stretch, .nonbonded
        ])
    do {
//      var rigidBody = mechanism.parts[0].rigidBody
//      var positions = rigidBody.positions
//      for i in positions.indices {
//        var coords = positions[i]
//        coords = SIMD3(coords.y, coords.x, coords.z + 2)
//        positions[i] = coords
//      }
//      rigidBody.setPositions(positions)
//      rigidBody.linearVelocity = SIMD3(0, 0, -1)
//      mechanism.parts[1].rigidBody = rigidBody
    }
    mechanism.initializeVelocities()
//    print(mechanism.parts.map(\.rigidBody).map(\.linearVelocity))
//    print(mechanism.parts.map(\.rigidBody).map(\.angularVelocity))
//    print(mechanism.linearVelocities)
//    print(mechanism.angularVelocities)
//    exit(0)
//    return [Self.createEntities(mechanism.parts.map(\.rigidBody))]
    
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
    var minimizer = TopologyMinimizer(descriptor: descriptor)
    if !rigidBodyDynamics {
      minimizer.minimize()
    }
    
    // Define an acceptable threshold of energy drift per atom, in yJ.
    let atomCount = mechanism.parts.reduce(0) { $0 + $1.rigidBody.parameters.atoms.count }
    let thresholdInYJ = Double(10) * Double(atomCount)
    let thresholdInZJ = thresholdInYJ / 1000
    
    let potentialBase = minimizer.createPotentialEnergy()
    var output: [[Entity]] = []
    var maxJ: Int = 1
    var originalSavePoint: (energy: Double, mechanism: NCFMechanism)?
    var savePoint: (energy: Double, mechanism: NCFMechanism)?
    var timeSinceSave = 0
    
    var i = 0
    let timeStep: Double = 0.160
    while i < 70 {
      //      print()
      //      print(mechanism.parts.map(\.rigidBody).map(\.linearVelocity))
      //      print(mechanism.parts.map(\.rigidBody).map(\.angularVelocity))
      //      print(mechanism.linearVelocities)
      //      print(mechanism.angularVelocities)
      if i > 0 {
        if rigidBodyDynamics {
          // Simulate evolution for one timestep.
          for j in 0..<maxJ {
            let time = Double(maxJ * i + j) * (timeStep / Double(maxJ))
            mechanism.evolve(timeStep: (timeStep / Double(maxJ)), start: j == 0, end: j + 1 == maxJ, minimizer: &minimizer)
          }
        } else {
          minimizer.simulate(time: timeStep)
          for partID in mechanism.parts.indices {
            let atomRange = mechanism.atomRange(partID: partID)
            var rigidBody = mechanism.parts[partID].rigidBody
            minimizer.export(to: &rigidBody, range: atomRange)
            mechanism.parts[partID].rigidBody = rigidBody
          }
        }
      }
      
      // Angular momentum is not being conserved with rigid body dynamics now.
      // I don't know why. With molecular dynamics, it's always zero. But with
      // rigid body dynamics, it drifts to something larger. Energy is still
      // conserved though.
      let potential = minimizer.createPotentialEnergy() - potentialBase
      let kinetic = rigidBodyDynamics ? mechanism.createKineticEnergy() : minimizer.createKineticEnergy()
      
      let twiceMinTimeStepInFs = 1.1 * 2 // the timestep cannot fall under 1 fs.
      if rigidBodyDynamics,
         let originalSavePoint,
         let savePoint,
          abs(potential + kinetic - originalSavePoint.energy) > thresholdInZJ,
         1e3 * timeStep / Double(maxJ) > twiceMinTimeStepInFs {
        print("=== RECOVER SYSTEM ===, \(1e3 * timeStep / Double(maxJ))")
        mechanism = savePoint.mechanism
        maxJ *= 2
        timeSinceSave = 0
        
        // Update the simulator so it can compute forces for the next timestep.
        var positions: [SIMD3<Float>] = []
        for partID in mechanism.parts.indices {
          positions +=  mechanism.parts[partID].rigidBody.positions
        }
        minimizer.setPositions(positions)
      } else {
        let rigidBodyStep = 1e3 * timeStep / Double(maxJ)
        let quantity = mechanism.createAngularMomentum()
        print("time=\(String(format: "%.2f", Double(i) * timeStep)) step=\(rigidBodyDynamics ? rigidBodyStep : 2.0) fs: \(Float(potential + kinetic)) zJ, \(quantity.x) \(quantity.y) \(quantity.z)")
        output.append(Self.createEntities(mechanism.parts.map(\.rigidBody)))
        i += 1
        timeSinceSave += 1
        
        // Occasionally sample whether it's okay to raise the timestep.
        if timeSinceSave > 4 && maxJ > 1 {
          maxJ /= 2
        }
        
        savePoint = (Double(potential + kinetic), mechanism)
        if originalSavePoint == nil {
          originalSavePoint = savePoint
        }
      }
    }
    return output
  }
}

extension NCFMechanism {
  func createKineticEnergy() -> Double {
    var output: Double = 0
    for partID in parts.indices {
      let rigidBody = parts[partID].rigidBody
      let I = rigidBody.momentOfInertia
//      let w = rigidBody.angularVelocity
      let w = SIMD3<Float>(angularVelocities[partID])
      let Iw = I.0 * w.x + I.1 * w.y + I.2 * w.z
      let wIw = (w * Iw).sum()
      
      let m = rigidBody.mass
//      let v = rigidBody.linearVelocity
      let v = SIMD3<Float>(linearVelocities[partID])
      let mv = m * v
      let vmv = (v * mv).sum()
      
      output += Double(0.5 * wIw + 0.5 * vmv)
    }
    return output
  }
  
  // To troubleshoot the energy explosion, check that other physical quantities
  // are being conserved.
  
  func createCenterOfMass() -> SIMD3<Float> {
    var accumulator: SIMD3<Double> = .zero
    var mass: Double = .zero
    for rigidBody in parts.map(\.rigidBody) {
      accumulator += SIMD3(rigidBody.centerOfMass * rigidBody.mass)
      mass += Double(rigidBody.mass)
    }
    return SIMD3(accumulator / mass)
  }
  
  func createLinearMomentum() -> SIMD3<Float> {
    var accumulator: SIMD3<Double> = .zero
    for partID in parts.indices {
      let rigidBody = parts[partID].rigidBody
      let momentum = rigidBody.mass * SIMD3<Float>(linearVelocities[partID])
      accumulator += SIMD3(momentum)
    }
    return SIMD3(accumulator)
  }
  
  func createAngularMomentum() -> SIMD3<Float> {
    var accumulator: SIMD3<Double> = .zero
    let center = SIMD3<Float>.zero//createCenterOfMass()
    for partID in parts.indices {
      let rigidBody = parts[partID].rigidBody
      let masses = rigidBody.parameters.atoms.masses
      var momenta: [SIMD3<Float>] = []
      let rigidBodyCoM = rigidBody.centerOfMass
      
      let v = SIMD3<Float>(linearVelocities[partID])
      let w = SIMD3<Float>(angularVelocities[partID])
      for (mass, position) in zip(masses, rigidBody.positions) {
        let r = position - rigidBodyCoM
        let velocity = v + cross_platform_cross(w, r)
        momenta.append(mass * velocity)
      }
      
      let positions = rigidBody.positions
      for (position, momentum) in zip(positions, momenta) {
        let r = position - center
        let L = cross_platform_cross(r, momentum)
        accumulator += SIMD3<Double>(L)
      }
    }
    return SIMD3(accumulator)
  }
}

extension NCFMechanism {
  // WARNING: Always call this before starting a simulation.
  mutating func initializeVelocities() {
    precondition(linearVelocities.count == 0)
    precondition(angularVelocities.count == 0)
    for rigidBody in parts.map(\.rigidBody) {
      linearVelocities.append(SIMD3(rigidBody.linearVelocity))
      angularVelocities.append(SIMD3(rigidBody.angularVelocity))
    }
  }
  
  // TODO: Try avoiding the frequent unit conversions between zJ and kJ/mol.
  // They may contribute somewhat to the rounding error that creates nonzero
  // angular acceleration for the isolated object.
  // Evolve the system for a single time step, using Verlet integration.
  mutating func evolve(
    timeStep: Double,
    start: Bool,
    end: Bool,
    minimizer: inout TopologyMinimizer
  ) {
    // Source code from MM4, minimized to only include force group 1.
    /*
     if descriptor.start {
       integrator.addComputePerDof(variable: "v", expression: """
         v + 0.5 * dt * f1 / m
         """)
     } else {
       integrator.addComputePerDof(variable: "v", expression: """
         v + 1.0 * dt * f1 / m
         """)
     }
     
     integrator.addComputePerDof(variable: "x", expression: """
       x + 1.0 * dt * v
       """)
     
     if descriptor.end {
       integrator.addComputePerDof(variable: "v", expression: """
         v + 0.5 * dt * f1 / m
         """)
     }
     */
    
    if start {
      let forces = minimizer.createForces()
      _evolve(
        velocityTimeStep: 0.5 * timeStep,
        positionTimeStep: 1.0 * timeStep,
        forces: forces)
    } else {
      let forces = minimizer.createForces()
      _evolve(
        velocityTimeStep: 1.0 * timeStep,
        positionTimeStep: 1.0 * timeStep,
        forces: forces)
    }
    
    // Update the simulator so it can compute forces for the next timestep.
    var positions: [SIMD3<Float>] = []
    for partID in parts.indices {
      positions += parts[partID].rigidBody.positions
    }
    minimizer.setPositions(positions)
    
    if end {
      let forces = minimizer.createForces()
      _evolve(
        velocityTimeStep: 0.5 * timeStep,
        positionTimeStep: 0,
        forces: forces)
    }
  }
  
  mutating func _evolve(
    velocityTimeStep: Double,
    positionTimeStep: Double,
    forces: [SIMD3<Float>]
  ) {
    let indexToPrint = -1
    for i in parts.indices {
      if i == indexToPrint {
        print("rigid body \(i) @ \(velocityTimeStep) \(positionTimeStep):")
      }
      var rigidBody = parts[i].rigidBody
      defer { parts[i].rigidBody = rigidBody }
      
      // Fetch the force and torque on each atom.
      let mass = rigidBody.mass
      let centerOfMass = rigidBody.centerOfMass
      let I = rigidBody.momentOfInertia
      
      let atomRange = atomRange(partID: i)
      let atomForces = Array(forces[atomRange])
      let atomTorques = zip(rigidBody.positions, atomForces).map { p, F in
        // An improved version of this would operate directly on the vectorized
        // atom positions and velocities.
        let r = p - centerOfMass
        return cross_platform_cross(r, F)
      }
      
      // Evaluate bulk force and torque.
      var forceAccumulator: SIMD3<Double> = .zero
      var torqueAccumulator: SIMD3<Double> = .zero
      for i in rigidBody.parameters.atoms.indices {
        forceAccumulator += SIMD3<Double>(atomForces[i])
        torqueAccumulator += SIMD3<Double>(atomTorques[i])
      }
      let force = SIMD3<Float>(forceAccumulator)
      let torque = SIMD3<Float>(torqueAccumulator)
      
      let linearAcceleration = force / mass
      let inverseI = cross_platform_inverse3x3(I)
      let angularAcceleration =
      inverseI.0 * torque.x + inverseI.1 * torque.y + inverseI.2 * torque.z
      
      func repr(_ vector: SIMD3<Float>) -> String {
        let angle = (vector * vector).sum().squareRoot()
        let axis = vector / angle
        return "\(angle) | \(axis.x) \(axis.y) \(axis.z)"
      }
      
      // Update atom velocities according to force and torque.
      var linearVelocity = self.linearVelocities[i]
      var angularVelocity = self.angularVelocities[i]
      if i == indexToPrint {
        print("- before:")
        print("  - center of mass: \(centerOfMass.x) \(centerOfMass.y) \(centerOfMass.z)")
        print("  - linear velocity: \(Float(linearVelocity.x)) \(Float(linearVelocity.y)) \(Float(linearVelocity.z))")
        print("  - angular velocity: \(repr(SIMD3<Float>(angularVelocity)))")
        print("  - torque: \(repr(torque))")
        print("  - atom position 0: \(rigidBody.positions[0])")
        print("  - atom position 1: \(rigidBody.positions[1])")
        print("  - atom force 0: \(forces[0])")
        print("  - atom force 1: \(forces[1])")
      }
      
//      print(linearVelocity, angularVelocity, centerOfMass)
      
      var maxDistance: Float = 0
      var minDistance: Float = .greatestFiniteMagnitude
      for position in rigidBody.positions {
        let delta = position - centerOfMass
        let distance = (delta * delta).sum().squareRoot()
        minDistance = min(minDistance, distance)
        maxDistance = max(maxDistance, distance)
      }
//      print("-", minDistance, maxDistance)
      
      linearVelocity += velocityTimeStep * SIMD3<Double>(linearAcceleration)
      angularVelocity += velocityTimeStep * SIMD3<Double>(angularAcceleration)
      self.linearVelocities[i] = linearVelocity
      self.angularVelocities[i] = angularVelocity
      if i == indexToPrint {
        print("- after:")
        print("  - linear velocity: \(Float(linearVelocity.x)) \(Float(linearVelocity.y)) \(Float(linearVelocity.z))")
        print("  - angular velocity: \(repr(SIMD3<Float>(angularVelocity)))")
      }
      
      guard positionTimeStep > 0 else {
        continue
      }
      
      let linearDisplacement = Float(positionTimeStep) * SIMD3<Float>(linearVelocity)
      let angularDisplacement = Float(positionTimeStep) * SIMD3<Float>(angularVelocity)
      let angularDisplacementQ = vector_to_quaternion(angularDisplacement)
      var rotation = (
        angularDisplacementQ.act(on: SIMD3<Float>(1, 0, 0)),
        angularDisplacementQ.act(on: SIMD3<Float>(0, 1, 0)),
        angularDisplacementQ.act(on: SIMD3<Float>(0, 0, 1)))
      
      var failedToRotate = false
      for vector in [rotation.0, rotation.1, rotation.2] {
        let length = (vector * vector).sum().squareRoot()
        guard length > 0.9 && length < 1.1 else {
          failedToRotate = true
          break
        }
      }
      if failedToRotate {
        rotation = (SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
      }
      
      // Update atom positions according to bulk velocity.
      var newPositions: [SIMD3<Float>] = []
      var newVelocities: [SIMD3<Float>] = []
      for position in rigidBody.positions {
        // Apply the angular displacement. An improved version of this would
        // operate directly on the vectorized atom positions and velocities.
        var r = position - centerOfMass
        r = rotation.0 * r.x + rotation.1 * r.y + rotation.2 * r.z
        
        // Make the particle's velocity rotate as well, so it agrees with bulk
        // angular velocity. This is the source of the bug with rigid body
        // mechanics.
        let v = cross_platform_cross(SIMD3<Float>(angularVelocity), r)
        newPositions.append(centerOfMass + linearDisplacement + r)
        newVelocities.append(SIMD3<Float>(linearVelocity) + v)
      }
      rigidBody.setPositions(newPositions)
      
      // We don't use the velocities of individual particles to save the rigid
      // body's state. I don't know why, but there was major numerical error
      // when I did that. It could have been from a bug somewhere else; I don't
      // know. It will be a worthy effort to re-enable this form of state
      // storage, proving precision of linear/angular velocity is preserved.
//      rigidBody.setVelocities(newVelocities)
//      if i == indexToPrint {
//        print("  - angular velocity: \(repr(rigidBody.angularVelocity))")
//      }
    }
  }
}
