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
    // Bypass Swift compiler warnings about dead code.
    let rigidBodyDynamics = Bool.random() ? true : true
    
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

extension NCFMechanism {
  // Investigate how the moment of inertia changes during a rotation. Can the
  // final value be predicted beforehand? If so, that enables some optimizations
  // in the MM4RigidBody backend.
  //
  // The code for NCFMechanism is about to break, as MM4RigidBody gets
  // rewritten to store bulk properties in double precision. This design
  // change lets properties be cached across successive timesteps, with
  // minimal drift from rounding error. There are ways to refresh the cached
  // properties and synchronize with actual atom positions/velocities.
  //
  // Nevermind: the source of rounding error may have been use of such
  // small timesteps (2 fs). Larger timesteps (80 fs) may have the same
  // effect as in molecular dynamics. In addition, the frequent
  // recomputation of bulk properties introduced numerical error. Until you
  // have 100% hard evidence, do not change the internal representation from
  // Float32 to Float64. If it is necessary, delaying the change and
  // understanding exactly why it's necessary would be more insightful
  // anyways.
  static func simulationExperiment5() -> [[Entity]] {
    func displayMatrix(
      _ M: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>),
      leftPlaces: Int,
      rightPlaces: Int
    ) {
      func fmt(_ number: Float) -> String {
        var output = String(format: "%.\(rightPlaces)f", number)
        while output.count < leftPlaces + 1 + rightPlaces {
          output = " " + output
        }
        return output
      }
      print("[\(fmt(M.0.x)) \(fmt(M.1.x)) \(fmt(M.2.x))]")
      print("[\(fmt(M.0.y)) \(fmt(M.1.y)) \(fmt(M.2.y))]")
      print("[\(fmt(M.0.z)) \(fmt(M.1.z)) \(fmt(M.2.z))]")
    }
    
    var rigidBody = NCFPart().rigidBody
    let axis = cross_platform_normalize(
//      SIMD3<Float>(1, 0, 0))
//      SIMD3<Float>(0, 2, -1))
//    SIMD3<Float>(3.5, -9.1, -6.3))
      SIMD3<Float>.random(in: -1...1)) // try several times with random vectors to ensure you never encounter a case where 2+ matrices fail to invert
    let originalPositions = rigidBody.positions
    let originalMoment = rigidBody.momentOfInertia
    
    print()
    print("original inertia tensor")
    print()
    displayMatrix(rigidBody.momentOfInertia, leftPlaces: 6, rightPlaces: 3)
    
    var allOutputFrames: [[Entity]] = []
    
    for decade in 1...92 {
//    for decade in 0...0 {
      let angle = Float(decade * 2)
      let rotationQuaternion = Quaternion<Float>(
        angle: angle * .pi / 180,
        axis: axis)
      let rotationMatrix = (
        rotationQuaternion.act(on: SIMD3<Float>(1, 0, 0)),
        rotationQuaternion.act(on: SIMD3<Float>(0, 1, 0)),
        rotationQuaternion.act(on: SIMD3<Float>(0, 0, 1)))
      
      var positions: [SIMD3<Float>] = []
      for i in rigidBody.parameters.atoms.indices {
        let position = originalPositions[i]
        positions.append(cross_platform_gemv3x3(rotationMatrix, position))
      }
      rigidBody.setPositions(positions)
      
      func fmt(_ number: Float) -> String {
        var output = String(format: "%.3f", number)
        while output.count < 6 {
          output = " " + output
        }
        return output
      }
      print()
      print("\(angle)°", "|", fmt(axis.x), fmt(axis.y), fmt(axis.y))
      print()
      displayMatrix(rigidBody.momentOfInertia, leftPlaces: 6, rightPlaces: 3)
      
      #if false
      // apply transform F to turn A into B
      // B = F A
      // B A^-1 = F A A^-1
      // B A^-1 = F
      let newMoment = rigidBody.momentOfInertia
      let invOldMoment = cross_platform_inverse3x3(originalMoment)
      let oldToNew = cross_platform_gemm3x3(newMoment, invOldMoment)
      print()
      displayMatrix(oldToNew, leftPlaces: 3, rightPlaces: 3)
      print()
      displayMatrix(rotationMatrix, leftPlaces: 3, rightPlaces: 3)
      
      // Predict the new inertia tensor.
      let invRotationMatrix = cross_platform_inverse3x3(rotationMatrix)
      var newMomentPredicted = cross_platform_gemm3x3(originalMoment, invRotationMatrix)
      newMomentPredicted = cross_platform_gemm3x3(rotationMatrix, newMomentPredicted)
      print()
      displayMatrix(newMomentPredicted, leftPlaces: 3, rightPlaces: 3)
      
      // Try an alternative method with less numerical error.
      var rotationMatrixT: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
      do {
        let M = rotationMatrix
        rotationMatrixT = (
          SIMD3(M.0.x, M.1.x, M.2.x),
          SIMD3(M.0.y, M.1.y, M.2.y),
          SIMD3(M.0.z, M.1.z, M.2.z))
      }
      newMomentPredicted = cross_platform_gemm3x3(originalMoment, rotationMatrixT)
      newMomentPredicted = cross_platform_gemm3x3(rotationMatrix, newMomentPredicted)
      print()
      displayMatrix(newMomentPredicted, leftPlaces: 3, rightPlaces: 3)
      #endif
      
      // For some problems, the 1st method has less rounding error. For others,
      // the 2nd method has less rounding error. The optimal solution:
      // - 1) Use the matrix transpose instead of inverse operation.
      // - 2) Perform all intermediate computations in Float64.*
      // - 3) Never round off the final result to Float32.
      //
      // Keep the moment of inertia in Float64 across timesteps. Only cast to
      // Float32 when presenting through the public API.
      //
      // *Intermediate computations on the scalar bulk quantity. Cast to FP32
      // before adjusting individual atom positions. We need to maximize
      // execution speed on the CPU. Interesting idea:
      // - Store the vectorized positions as the last time they were modified
      // - Compute the scalarized positions as an analytical function of the
      //   saved state and recorded mutation to inertia/position
      // - Remove vectorizedPositions and vectorizedVelocities from the API.
      // - We never need to recompute the vectorized positions. Only accept new
      //   positions specified by the user.
      // - Similarly, we can store the velocities as an update over the last
      //   save state. The computation method has to effectively separate out
      //   and rotate the thermal component of velocity.
      // - Store a local 3x3 matrix accumulating the cached updates to
      //   position/velocity.
      //
      // - Store only the thermal velocities in vVelocities. That partially
      //   simplifies the function setThermalKineticEnergy().
      // - Store vPositions in a local basis as well. All of the data is stored
      //   relative to the center of mass / bulk momentum. None of it is rotated
      //   to match the current reference frame.
      // - Forces need to be different. The user must be able to specify the
      //   forces from an external simulator, so we can't hide them and only
      //   expose bulk variables. Rather, vForces are stored and the netForce/
      //   netTorque are computed/cached together. They only have getters, not
      //   setters.
      // - Remove externalForces from MM4RigidBody and only expose in
      //   MM4ForceField. Change the property so it only has a setter, and no
      //   getter. Use a function similar to setPositions or
      //   setThermalKineticEnergy.
      // - Add exportForces to MM4ForceField and remove all other rigid body
      //   I/O functions for now. There is already functionality for importing
      //   the initial positions/velocities of rigid bodies prior to a
      //   molecular dynamics simulation.
      //   - Except, we need to modify the force field's state to calculate
      //     potential energy during a rigid body dynamics simulation.
      //   - And, we need to import thermal velocities for NVT-like simulations.
      //   - Add functions importPositions and importVelocities, but not the
      //     analogues for exporting yet. That removes the need to unit test
      //     certain state mutations onto the rigid body.
      //   - Recycle these functions when importing rigid body states during
      //     the convenience initializer (what became of the initializer after
      //     MM4ForceFieldDescriptor was added).
      //
      // - Don’t store forces as vectorized; don’t expose public API for
      //   vectorized positions and velocities. The method with the least amount
      //   of work is de-swizzling the forces on the fly. De-swizzling happens
      //   the one and only time they are read: when computing 'netForce' and
      //   'netTorque' simultaneously.
      //
      // /// Rotates around the axis defined by `angularVelocity`.
      // mutating func rotate(angle: Float)
      
      // MARK: - Experiment with Diagonalizing the Inertia Tensor
      
      // After we have a formula to diagonalize the matrix, test it here.
      // Analyze what happens to the matrix as it undergoes each increment of
      // rotation.
      
      // Trying to understand what GPT-4 did here. It wrote the exact same
      // function call 3 times. Here are the arguments, rewritten in a way that
      // sort of makes sense. I'll use the original formula verbatim (with
      // minimal tweaks) and leave this to explain it. The original formula is
      // being used to minimize the chance of accidental human errors.
      /*
       // Find the eigenvalues of the inertia tensor using the bisection method
       // The coefficients of the characteristic equation are -1, -(a + b + c), ab + bc + ca, -abc
       
      let (a, b, c) = diagonal
      let xy = I[0][1] = I[1][0]
      let xz = I[0][2] = I[2][0]
      let yz = I[1][2] = I[2][1]
        lambda[0] = bisection(
          -1,
           -a - b - c,
           
           a * b +
           b * c +
           a * c
           - xy * xy
           - yz * yz
           - xz * xz,
           
           -a * b * c
           + a * yz * yz
           + b * xz * xz
           + c * xy * xy -
           - 2 * (xy * yz * xz));
       
       //      coefficients[0] = -1
       //      coefficients[1] = -I.0[0] - I.1[1] - I.2[2]
       //      coefficients[2] =
       //      I.0[0] * I.1[1]
       //      + I.1[1] * I.2[2]
       //      + I.0[0] * I.2[2]
       //      - I.0[1] * I.1[0]
       //      - I.1[2] * I.2[1]
       //      - I.0[2] * I.2[0]
       //      coefficients[3] =
       //      -I.0[0] * I.1[1] * I.2[2]
       //      + I.0[0] * I.1[2] * I.2[1]
       //      + I.0[1] * I.1[0] * I.2[2]
       //      - I.0[1] * I.1[2] * I.2[0]
       //      - I.0[2] * I.1[0] * I.2[1]
       //      + I.0[2] * I.1[1] * I.2[0]
       */
      
      var coefficients: SIMD4<Double> = .zero
      var I: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)

      // CP = [-1, tr(A), -0.5 * [tr(A)^2 - tr(A^2)], det(A)]
      do {
        // Cast to FP64 to increase numerical stability.
        let I_fp32 = rigidBody.momentOfInertia
        I = (SIMD3<Double>(I_fp32.0),
                 SIMD3<Double>(I_fp32.1),
                 SIMD3<Double>(I_fp32.2))
        
        let I2 = cross_platform_gemm3x3(I, I)
        let trA = I.0[0] + I.1[1] + I.2[2]
        let trA2 = I2.0[0] + I2.1[1] + I2.2[2]
        let detA =
        I.0[0] * (I.1[1] * I.2[2] - I.2[1] * I.1[2]) -
        I.0[1] * (I.1[0] * I.2[2] - I.1[2] * I.2[0]) +
        I.0[2] * (I.1[0] * I.2[1] - I.1[1] * I.2[0])
        
        coefficients[0] = -1
        coefficients[1] = trA
        coefficients[2] = -0.5 * (trA * trA - trA2)
        coefficients[3] = detA
      }
      
      
      
      
//      print("coefficients:", coefficients)
      let roots = NCFMechanism.solveCubicEquation(coefficients: coefficients, debugResults: false)
//      print()
//      print("roots: \(SIMD2<Double>(SIMD2<Float>(roots.0))) \(SIMD2<Double>(SIMD2<Float>(roots.1))) \(SIMD2<Double>(SIMD2<Float>(roots.2)))")
      
      for root in [roots.0, roots.1, roots.2] {
        let rootRounded = SIMD2<Double>(SIMD2<Float>(root))
        var output = ""
        output += "\n  \(coefficients[0]) * \(rootRounded)^3 + "
        output += "\(coefficients[1]) * \(rootRounded)^2 + "
        output += "\(coefficients[2]) * \(rootRounded)^1 + "
        output += "\(coefficients[3]) = \n  "
        
        let root0 = SIMD2<Double>(1, 0)
        let root1 = root
        let root2 = NCFMechanism.complexMultiply(root1, root1)
        let root3 = NCFMechanism.complexMultiply(root2, root1)
        
        var rhs: SIMD2<Double> = .zero
        rhs += coefficients[3] * root0
        rhs += coefficients[2] * root1
        rhs += coefficients[1] * root2
        rhs += coefficients[0] * root3
        
        // Although the results are not zero (they have a magnitude of ~1.0 for
        // the real component), it's understandable why that is the case. They
        // were adding and subtracting extremely massive numbers. 1 would fall
        // roughly at the ulp of 10^13.
        //
        // Roots for the original inertia tensor:
        // SIMD2<Double>(109983.7421875, 9.701277108031814e-12)
        // SIMD2<Double>(4043.4931640625, 0.0)
        // SIMD2<Double>(106430.8046875, -4.850638554015907e-12)
//        print(output + "\(rhs)")
      }
      
      let eigenValues: [Double] = [roots.0.x, roots.1.x, roots.2.x]
      var hadAFailure = false
      var failureCount = 0
      
      print("I=\(I)")
      
       var eigenVectors: [SIMD3<Double>] = []
      for eigenValue in eigenValues {
//        print()
//        print("eigenvalue \(eigenValue):")
        var B = I as (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>)
        B.0.x -= eigenValue
        B.1.y -= eigenValue
        B.2.z -= eigenValue
        
        var trialID = 0
        while true {
          trialID += 1
          if trialID > 10 {
            fatalError("Failed to diagonalize the inertia tensor.")
          }
          
          let B_inv = cross_platform_inverse3x3(B)
          
          // All 3 of the matrix's columns are a multiple of the same vector! It
          // is a singular matrix.
          var chosenVector: SIMD3<Double>?
          for candidate in [B_inv.0, B_inv.1, B_inv.2] {
            let length = (candidate * candidate).sum().squareRoot()
            let normalized = candidate / length
  //          let Ev = cross_platform_gemv3x3(I, normalized)
  //          let λ = (Ev * Ev).sum().squareRoot()
            
            if !normalized.x.isNaN {
              chosenVector = normalized
            }
            
  //          print("  - candidate: \(λ) | \(normalized)")
          }
          guard let chosenVector else {
            print("Could not invert matrix: \(B) \(B_inv)")
            hadAFailure = true
            failureCount += 1
            
            // We'll have to fix the fact that eigenvectors are sometimes NAN.
            // If only one is NAN, we might be able to recover it using the cross
            // product. Otherwise, we'll need something more convoluted like
            // Gaussian elimination.
            
            // Adding some noise makes the matrix no longer singular. So far,
            // this has converged after 1 try. We provide a budget of 10
            // retries.
            B.0.x *= 1 + 1e-10
            B.1.y *= 1 + 1e-10
            B.2.z *= 1 + 1e-10
            print("Retrying with: \(B) \(cross_platform_inverse3x3(B))")
//            eigenVectors.append([42, 0, 0])
            continue
          }
          
          
          eigenVectors.append(chosenVector)
          break
        }
        
       
      }
      
      if eigenVectors.filter({ $0 == [42, 0, 0] }).count > 0 {
        fatalError("The cross-product path was deactivated.")
        if eigenVectors.filter({ $0 == [42, 0, 0] }).count > 1 {
          fatalError("Too many eigenvectors were NAN.")
        } else {
          let otherVectors = eigenVectors.filter { $0 != [42, 0, 0] }
          guard otherVectors.count == 2 else {
            fatalError("This should never happen.")
          }
          let crossProduct = cross_platform_cross(SIMD3<Float>(otherVectors[0]), SIMD3<Float>(otherVectors[1]))
          for i in eigenVectors.indices {
            if eigenVectors[i] == [42, 0, 0] {
              eigenVectors[i] = SIMD3<Double>(crossProduct)
              print("recovered eigenvector: \(eigenValues[i]) | \(crossProduct)")
            }
          }
        }
      }
      
      // Establish a rule so the eigenvectors don't keep flashing back and
      // forth between different directions.
      for eigenPairID in eigenVectors.indices {
        var chosenVector = eigenVectors[eigenPairID]
        var flip = false
        if chosenVector.x != 0 {
          flip = chosenVector.x > 0
        } else if chosenVector.y != 0 {
          flip = chosenVector.y < 0
        } else {
          flip = chosenVector.z < 0
        }
        if flip {
          chosenVector = -chosenVector
        }
        eigenVectors[eigenPairID] = chosenVector
      }
      
      /*
      let eigenVectors = NCFMechanism.gaussianElimination(matrix: I, eigenValues: eigenValues)
       */
      
      var thisFrameAtoms: [Entity] = []
      var eigenVectorAtomicNumber: UInt8 = 9
      // green (F) = 1st
      // red   (O) = 2nd
      // blue  (N) = 3rd
      
      print()
      for (eigenValue, eigenVector) in zip(eigenValues, eigenVectors).sorted(by: { $0.0 > $1.0 }) {
        print("- eigenpair: \(Float(eigenValue)) | \(SIMD3<Float>(eigenVector))")
        
        
        // Use the square root of the ratio, so it's proportional to the ratio
        // of object dimensions. We used the square operation when creating
        // the inertia tensor.
        let ratio = (eigenValue / eigenValues.max()!).squareRoot()
        var distance: Double = 0
        
        // Make the eigenvectors stretch out for 5 nanometers.
        while distance < 5 * ratio {
          distance += 0.050
          let atomPosition = SIMD3<Float>(distance * eigenVector)
          thisFrameAtoms.append(Entity(position: atomPosition, type: .atom(Element(rawValue: hadAFailure ? 14 : eigenVectorAtomicNumber)!)))
        }
        
        eigenVectorAtomicNumber -= 1
      }
      
      if failureCount >= 2 {
        print("Found worthy test case.")
        exit(0)
      }
      
      /*
        // Print the eigenvalues
        printf("The eigenvalues are:\n");
        for (int i = 0; i < 3; i++) {
          printf("%f\n", lambda[i]);
        }
        // Find the eigenvectors of the inertia tensor using Gaussian elimination
        eigen(I, lambda, v);
        // Print the eigenvectors
        printf("The eigenvectors are:\n");
        for (int i = 0; i < 3; i++) {
          print_vector(v[i]);
        }
        // Construct the matrix of eigenvectors
        for (int i = 0; i < 3; i++) {
          P.a[0][i] = v[i].x;
          P.a[1][i] = v[i].y;
          P.a[2][i] = v[i].z;
        }
        // Print the matrix of eigenvectors
        printf("The matrix of eigenvectors is:\n");
        print_matrix(P);
        // Find the inverse of the matrix of eigenvectors
        P_inv = invert(P);
        // Print the inverse of the matrix of eigenvectors
        printf("The inverse of the matrix of eigenvectors is:\n");
        print_matrix(P_inv);
        // Diagonalize the inertia tensor using the formula D = P_inv * I * P
        D = multiply(multiply(P_inv, I), P);
        // Print the diagonalized inertia tensor
        printf("The diagonalized inertia tensor is:\n");
        print_matrix(D);
        // Return 0 to indicate successful execution
        return 0;
       }
      */
      
      // MARK: - Unit Tests for Eigendecomposition of the Inertia Tensor
      
      /*
       original inertia tensor

       [  4049.466   -782.010     -0.000]
       [  -782.010 106424.828     -0.000]
       [    -0.000     -0.000 109983.742]

       10.0° |  1.000  0.000  0.000

       [  4049.468   -770.131   -135.795]
       [  -770.131 106532.141   -608.610]
       [  -135.795   -608.610 109876.430]

       - eigenpair: 109983.74 | SIMD3<Float>(-1.4592249e-06, -0.17364776, 0.98480785)
       - eigenpair: 106430.8 | SIMD3<Float>(-0.0076380027, 0.98477906, 0.17364302)
       - eigenpair: 4043.4949 | SIMD3<Float>(-0.99997085, -0.0075219646, -0.0013263224)

       20.0° |  1.000  0.000  0.000

       [  4049.466   -734.850   -267.464]
       [  -734.850 106841.125  -1143.814]
       [  -267.464  -1143.814 109567.414]

       - eigenpair: 109983.73 | SIMD3<Float>(-8.911204e-08, -0.34202006, 0.9396927)
       - eigenpair: 106430.78 | SIMD3<Float>(0.0076379967, -0.93966526, -0.34201008)
       - eigenpair: 4043.4932 | SIMD3<Float>(0.99997085, 0.0071773687, 0.0026123496)

       30.0° |  1.000  0.000  0.000

       [  4049.467   -677.242   -391.005]
       [  -677.242 107314.539  -1541.056]
       [  -391.005  -1541.056 109094.000]

       - eigenpair: 109983.73 | SIMD3<Float>(-9.233208e-07, 0.49999985, -0.8660255)
       - eigenpair: 106430.78 | SIMD3<Float>(0.007637999, -0.8660003, -0.4999851)
       - eigenpair: 4043.494 | SIMD3<Float>(-0.99997085, -0.0066147023, -0.0038189972)

       40.0° |  1.000  0.000  0.000

       [  4049.468   -599.055   -502.667]
       [  -599.055 107895.273  -1752.424]
       [  -502.667  -1752.424 108513.273]

       - eigenpair: 109983.734 | SIMD3<Float>(-1.0875323e-06, -0.64278734, 0.7660447)
       - eigenpair: 106430.79 | SIMD3<Float>(0.0076379958, -0.76602215, -0.6427688)
       - eigenpair: 4043.4949 | SIMD3<Float>(0.99997085, 0.005851044, 0.00490961)

       50.0° |  1.000  0.000  0.000

       [  4049.468   -502.667   -599.055]
       [  -502.667 108513.289  -1752.425]
       [  -599.055  -1752.425 107895.289]

       - eigenpair: 109983.75 | SIMD3<Float>(-2.4222502e-06, 0.76604486, -0.64278716)
       - eigenpair: 106430.805 | SIMD3<Float>(0.0076379925, -0.6427688, -0.76602215)
       - eigenpair: 4043.495 | SIMD3<Float>(-0.99997085, -0.004909607, -0.0058510415)

       60.0° |  1.000  0.000  0.000

       [  4049.468   -391.006   -677.241]
       [  -391.006 109094.016  -1541.056]
       [  -677.241  -1541.056 107314.562]

       - eigenpair: 109983.75 | SIMD3<Float>(-2.2484057e-06, -0.86602485, 0.500001)
       - eigenpair: 106430.805 | SIMD3<Float>(0.007637995, -0.499986, -0.8659998)
       - eigenpair: 4043.495 | SIMD3<Float>(-0.99997085, -0.0038189993, -0.0066146962)

       70.0° |  1.000  0.000  0.000

       [  4049.467   -267.464   -734.850]
       [  -267.464 109567.414  -1143.814]
       [  -734.850  -1143.814 106841.125]

       - eigenpair: 109983.73 | SIMD3<Float>(-1.8781752e-06, 0.93969274, -0.34201977)
       - eigenpair: 106430.78 | SIMD3<Float>(0.0076379976, -0.34201017, -0.9396652)
       - eigenpair: 4043.494 | SIMD3<Float>(0.99997085, 0.0026123498, 0.0071773697)

       80.0° |  1.000  0.000  0.000

       [  4049.468   -135.795   -770.131]
       [  -135.795 109876.430   -608.611]
       [  -770.131   -608.611 106532.148]

       - eigenpair: 109983.74 | SIMD3<Float>(-8.329109e-07, 0.9848077, -0.17364843)
       - eigenpair: 106430.805 | SIMD3<Float>(-0.007638003, 0.17364354, 0.98477894)
       - eigenpair: 4043.4944 | SIMD3<Float>(0.99997085, 0.001326325, 0.0075219646)

       90.0° |  1.000  0.000  0.000

       [  4049.466     -0.000   -782.010]
       [    -0.000 109983.742     -0.000]
       [  -782.010     -0.000 106424.828]

       - eigenpair: 109983.74 | SIMD3<Float>(-1.2692162e-05, -1.0, 2.87981e-06)
       - eigenpair: 106430.805 | SIMD3<Float>(-0.0076379897, 9.090486e-08, 0.99997085)
       - eigenpair: 4043.4932 | SIMD3<Float>(0.99997085, 7.704745e-10, 0.0076379897)
       */
      
      /*
       
       original inertia tensor

       [  4049.466   -782.010     -0.000]
       [  -782.010 106424.828     -0.000]
       [    -0.000     -0.000 109983.742]

       10.0° |  0.000  0.894  0.894

       [  7102.700   7063.030  16219.079]
       [  7063.030 105928.656  -1135.441]
       [ 16219.079  -1135.441 107426.695]

       - eigenpair: 109983.75 | SIMD3<Float>(0.15531562, -0.0060769385, 0.9878462)
       - eigenpair: 106430.805 | SIMD3<Float>(-0.07013358, -0.99752563, 0.0048903762)
       - eigenpair: 4043.4946 | SIMD3<Float>(-0.9853722, 0.07004075, 0.15535751)

       20.0° |  0.000  0.894  0.894

       [ 16133.357  13980.624  30519.664]
       [ 13980.624 104268.070  -4638.508]
       [ 30519.664  -4638.508 100056.523]

       - eigenpair: 109983.7 | SIMD3<Float>(0.30591223, -0.02412253, 0.9517541)
       - eigenpair: 106430.76 | SIMD3<Float>(-0.14577411, -0.989078, 0.021786107)
       - eigenpair: 4043.492 | SIMD3<Float>(0.94083345, -0.14540574, -0.3060875)

       30.0° |  0.000  0.894  0.894

       [ 30052.211  19119.611  41185.301]
       [ 19119.611 101656.625 -10076.827]
       [ 41185.301 -10076.827  88749.180]

       - eigenpair: 109983.734 | SIMD3<Float>(0.4472136, -0.05358959, 0.89282036)
       - eigenpair: 106430.79 | SIMD3<Float>(-0.21698543, -0.9748846, 0.050172657)
       - eigenpair: 4043.4963 | SIMD3<Float>(0.8677081, -0.21616691, -0.4476098)

       40.0° |  0.000  0.894  0.894

       [ 47180.438  21846.162  46936.547]
       [ 21846.162  98424.727 -16782.795]
       [ 46936.547 -16782.795  74852.820]

       - eigenpair: 109983.72 | SIMD3<Float>(nan, nan, nan)
       - eigenpair: 106430.77 | SIMD3<Float>(0.28160313, 0.95537686, -0.08918928)
       - eigenpair: 4043.4907 | SIMD3<Float>(-0.7682178, 0.28017434, 0.5756247)
       recovered eigenvector: 109983.71891591714 | SIMD3<Float>(-0.57492703, 0.093580924, -0.81283545)

       50.0° |  0.000  0.894  0.894

       [ 65452.133  21820.650  47085.102]
       [ 21820.650  94979.750 -23934.473]
       [ 47085.102 -23934.473  60026.141]

       - eigenpair: 109983.734 | SIMD3<Float>(-0.6851706, 0.14288588, -0.7142303)
       - eigenpair: 106430.8 | SIMD3<Float>(0.33766657, 0.931147, -0.1376467)
       - eigenpair: 4043.4966 | SIMD3<Float>(0.64538556, -0.33548316, -0.6862423)

       60.0° |  0.000  0.894  0.894

       [ 82663.453  19038.959  41616.652]
       [ 19038.959  91756.047 -30655.078]
       [ 41616.652 -30655.078  46038.535]

       - eigenpair: 109983.74 | SIMD3<Float>(-0.77459675, 0.19999957, -0.6)
       - eigenpair: 106430.8 | SIMD3<Float>(0.3834677, 0.90293205, -0.19407801)
       - eigenpair: 4043.494 | SIMD3<Float>(nan, nan, nan)
       recovered eigenvector: 4043.493889071387 | SIMD3<Float>(-0.50294375, 0.38041282, 0.7761016)

       70.0° |  0.000  0.894  0.894

       [ 96738.430  13833.156  31192.459]
       [ 13833.156  89162.156 -36119.215]
       [ 31192.459 -36119.215  34557.383]

       - eigenpair: 109983.71 | SIMD3<Float>(-0.84048676, 0.2631916, -0.47361612)
       - eigenpair: 106430.766 | SIMD3<Float>(0.41761842, 0.87158865, -0.25676477)
       - eigenpair: 4043.497 | SIMD3<Float>(0.3452201, -0.41359818, -0.8424723)

       80.0° |  0.000  0.894  0.894

       [105979.484   6831.616  17069.654]
       [  6831.616  87530.961 -39652.891]
       [ 17069.654 -39652.891  26947.564]

       - eigenpair: 109983.734 | SIMD3<Float>(-0.880839, 0.33054027, -0.3389185)
       - eigenpair: 106430.78 | SIMD3<Float>(0.43907982, 0.8380694, -0.32380337)
       - eigenpair: 4043.4932 | SIMD3<Float>(0.17700718, -0.43403092, -0.8833378)

       90.0° |  0.000  0.894  0.894

       [109271.977  -1116.872    949.448]
       [ -1116.872  87078.758 -40815.188]
       [   949.448 -40815.188  24107.334]

       - eigenpair: 109983.76 | SIMD3<Float>(-0.89442736, 0.3999997, -0.19999988)
       - eigenpair: 106430.81 | SIMD3<Float>(0.44720024, 0.80339265, -0.3931567)
       - eigenpair: 4043.4954 | SIMD3<Float>(0.0034158754, -0.4410901, -0.89745635)
       */
      
      /*
       
       original inertia tensor

       [  4049.466   -782.010     -0.000]
       [  -782.010 106424.828     -0.000]
       [    -0.000     -0.000 109983.742]

       10.0° |  0.302 -0.784 -0.784

       [  6786.336   9140.271 -14035.544]
       [  9140.271 105604.562   1077.542]
       [-14035.544   1077.542 108067.125]

       - eigenpair: 109983.734 | SIMD3<Float>(0.13861392, 0.045893345, -0.98928255)
       - eigenpair: 106430.8 | SIMD3<Float>(0.08311635, 0.9948623, 0.05779809)
       - eigenpair: 4043.4946 | SIMD3<Float>(0.9868525, -0.09023718, 0.13408728)

       20.0° |  0.302 -0.784 -0.784

       [ 14988.880  18721.973 -26066.104]
       [ 18721.973 102661.570   4843.333]
       [-26066.104   4843.333 102807.531]

       - eigenpair: 109983.72 | SIMD3<Float>(-0.27798817, -0.07746486, 0.9574559)
       - eigenpair: 106430.77 | SIMD3<Float>(-0.16414261, -0.9782524, -0.12680468)
       - eigenpair: 4043.4937 | SIMD3<Float>(0.94645643, -0.19240952, 0.2592273)

       30.0° |  0.302 -0.784 -0.784

       [ 27748.875  26787.699 -34814.973]
       [ 26787.699  97504.898  10952.274]
       [-34814.973  10952.274  95204.203]
       Could not invert matrix: (SIMD3<Double>(-82234.84168607595, 26787.69921875, -34814.97265625), SIMD3<Double>(26787.69921875, -12478.818248575946, 10952.2744140625), SIMD3<Double>(-34814.97265625, 10952.2744140625, -14779.513561075946)) (SIMD3<Double>(inf, inf, -inf), SIMD3<Double>(inf, inf, -inf), SIMD3<Double>(-inf, -inf, inf))
       recovered eigenvector: 109983.71668607595 | SIMD3<Float>(0.41388798, 0.09375615, -0.9054869)

       - eigenpair: 109983.72 | SIMD3<Float>(0.41388798, 0.09375615, -0.9054869)
       - eigenpair: 106430.77 | SIMD3<Float>(0.23297852, 0.9506457, 0.20492388)
       - eigenpair: 4043.49 | SIMD3<Float>(-0.88001007, 0.29577452, -0.37161765)

       40.0° |  0.302 -0.784 -0.784

       [ 43650.941  32289.797 -39427.980]
       [ 32289.797  90309.625  18746.305]
       [-39427.980  18746.305  86497.430]

       - eigenpair: 109983.72 | SIMD3<Float>(0.54218394, 0.0942708, -0.8349548)
       - eigenpair: 106430.78 | SIMD3<Float>(0.28753302, 0.9128811, 0.28978074)
       - eigenpair: 4043.4956 | SIMD3<Float>(-0.78953236, 0.39719152, -0.46784353)

       50.0° |  0.302 -0.784 -0.784

       [ 60939.469  34437.016 -39570.430]
       [ 34437.016  81509.359  27331.355]
       [-39570.430  27331.355  78009.242]

       - eigenpair: 109983.76 | SIMD3<Float>(-0.6589778, -0.07899367, 0.7480028)
       - eigenpair: 106430.82 | SIMD3<Float>(-0.32614848, -0.8661061, -0.37879735)
       - eigenpair: 4043.4927 | SIMD3<Float>(-0.6777724, 0.49357903, -0.544981)

       60.0° |  0.302 -0.784 -0.784

       [ 77725.430  32793.758 -35460.660]
       [ 32793.758  71757.102  35683.781]
       [-35460.660  35683.781  70975.531]

       - eigenpair: 109983.75 | SIMD3<Float>(-0.76072127, -0.048389822, 0.6472724)
       - eigenpair: 106430.805 | SIMD3<Float>(-0.3476508, -0.8117418, -0.46926978)
       - eigenpair: 4043.5024 | SIMD3<Float>(-0.548126, 0.5820083, -0.6006865)

       70.0° |  0.302 -0.784 -0.784

       [ 92208.320  27338.090 -27836.654]
       [ 27338.090  61858.945  42773.527]
       [-27836.654  42773.527  66390.766]

       - eigenpair: 109983.74 | SIMD3<Float>(0.8443226, 0.0033884414, -0.5358244)
       - eigenpair: 106430.8 | SIMD3<Float>(0.35138723, 0.75144005, 0.5584486)
       - eigenpair: 4043.4944 | SIMD3<Float>(0.4045322, -0.65979266, 0.6332672)

       80.0° |  0.302 -0.784 -0.784

       [102886.453  18470.988 -17859.629]
       [ 18470.988  52688.156  47688.988]
       [-17859.629  47688.988  64883.441]

       - eigenpair: 109983.75 | SIMD3<Float>(0.90724087, -0.054644696, -0.41704673)
       - eigenpair: 106430.805 | SIMD3<Float>(0.33724615, 0.6870333, 0.6436228)
       - eigenpair: 4043.4941 | SIMD3<Float>(-0.2513544, 0.7245683, -0.6417334)

       90.0° |  0.302 -0.784 -0.784

       [108730.711   6975.808  -6966.566]
       [  6975.808  45089.371  49748.707]
       [ -6966.566  49748.707  66638.031]

       - eigenpair: 109983.78 | SIMD3<Float>(-0.947566, 0.12394297, 0.29454523)
       - eigenpair: 106430.83 | SIMD3<Float>(-0.30565315, -0.6204782, -0.72220695)
       - eigenpair: 4043.5017 | SIMD3<Float>(0.09324642, -0.7743674, 0.6258276)
       */
      
      // MARK: - Visual Validation Test of Eigendecomposition
      
      // Visualize the rigid body along with its eigenvectors.
      for i in rigidBody.parameters.atoms.indices {
        let position = rigidBody.positions[i]
        let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[i]
        let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
        thisFrameAtoms.append(entity)
      }
      
      // Animate the rotation by keeping each eigenbasis active for 30 frames.
//      for _ in 0..<30/10 {
      do {
        allOutputFrames.append(thisFrameAtoms)
      }
    }
    return allOutputFrames
  }
}

extension NCFMechanism {
  // Solve a cubic equation and debug the results.
  static func simulationExperiment6() {
    // Record the expected cube roots, so you can unit test them later.
    
    // MARK: - Unit Test 0
    
     let coefficients: SIMD4<Double> = [1, -6, 11, -6]
//  roots: SIMD2<Double>(1.0, -1.1102230246251565e-16) SIMD2<Double>(3.0, -1.1102230246251565e-16) SIMD2<Double>(2.0, 7.401487051415874e-17)
//  1.0 * SIMD2<Double>(1.0, -1.1102230246251565e-16)^3 + -6.0 * SIMD2<Double>(1.0, -1.1102230246251565e-16)^2 + 11.0 * SIMD2<Double>(1.0, -1.1102230246251565e-16)^1 + -6.0 = SIMD2<Double>(0.0, -2.220446049250313e-16)
//  1.0 * SIMD2<Double>(3.0, -1.1102230246251565e-16)^3 + -6.0 * SIMD2<Double>(3.0, -1.1102230246251565e-16)^2 + 11.0 * SIMD2<Double>(3.0, -1.1102230246251565e-16)^1 + -6.0 = SIMD2<Double>(0.0, -2.220446049250313e-16)
//  1.0 * SIMD2<Double>(2.0, 7.401487051415874e-17)^3 + -6.0 * SIMD2<Double>(2.0, 7.401487051415874e-17)^2 + 11.0 * SIMD2<Double>(2.0, 7.401487051415874e-17)^1 + -6.0 = SIMD2<Double>(0.0, -7.40148683083439e-17)
    
    // MARK: - Unit Test 1
    
//    let coefficients: SIMD4<Double> = [1, 1, 7, 2]
//  roots: SIMD2<Double>(-0.2944532632827759, -0.0) SIMD2<Double>(-0.35277336835861206, -2.5822083950042725) SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)
//  1.0 * SIMD2<Double>(-0.2944532632827759, -0.0)^3 + 1.0 * SIMD2<Double>(-0.2944532632827759, -0.0)^2 + 7.0 * SIMD2<Double>(-0.2944532632827759, -0.0)^1 + 2.0 = SIMD2<Double>(9.818534874028728e-16, 0.0)
//  1.0 * SIMD2<Double>(-0.35277336835861206, -2.5822083950042725)^3 + 1.0 * SIMD2<Double>(-0.35277336835861206, -2.5822083950042725)^2 + 7.0 * SIMD2<Double>(-0.35277336835861206, -2.5822083950042725)^1 + 2.0 = SIMD2<Double>(2.6645352591003757e-15, 0.0)
//  1.0 * SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)^3 + 1.0 * SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)^2 + 7.0 * SIMD2<Double>(-0.35277336835861206, 2.5822083950042725)^1 + 2.0 = SIMD2<Double>(5.329070518200751e-15, 7.105427357601002e-15)
    
    // MARK: - Unit Test 2
    
//     let coefficients: SIMD4<Double> = [-1.0, 220458.03662109375, -12580728532.801353, 47331747116183.29]
//  roots: SIMD2<Double>(109983.7421875, 9.701277108031814e-12) SIMD2<Double>(4043.4931640625, 0.0) SIMD2<Double>(106430.8046875, -4.850638554015907e-12)
//  -1.0 * SIMD2<Double>(109983.7421875, 9.701277108031814e-12)^3 + 220458.03662109375 * SIMD2<Double>(109983.7421875, 9.701277108031814e-12)^2 + -12580728532.801353 * SIMD2<Double>(109983.7421875, 9.701277108031814e-12)^1 + 47331747116183.29 = SIMD2<Double>(-0.25, -0.003651555197887457)
//  -1.0 * SIMD2<Double>(4043.4931640625, 0.0)^3 + 220458.03662109375 * SIMD2<Double>(4043.4931640625, 0.0)^2 + -12580728532.801353 * SIMD2<Double>(4043.4931640625, 0.0)^1 + 47331747116183.29 = SIMD2<Double>(0.0529022216796875, 0.0)
//  -1.0 * SIMD2<Double>(106430.8046875, -4.850638554015907e-12)^3 + 220458.03662109375 * SIMD2<Double>(106430.8046875, -4.850638554015907e-12)^2 + -12580728532.801353 * SIMD2<Double>(106430.8046875, -4.850638554015907e-12)^1 + 47331747116183.29 = SIMD2<Double>(-0.25, -0.0017645461032371745)
    
    // MARK: - Experiment 6
    
    let roots = NCFMechanism.solveCubicEquation(coefficients: coefficients, debugResults: true)
    print()
    print("roots: \(SIMD2<Double>(SIMD2<Float>(roots.0))) \(SIMD2<Double>(SIMD2<Float>(roots.1))) \(SIMD2<Double>(SIMD2<Float>(roots.2)))")
    
    for root in [roots.0, roots.1, roots.2] {
      let rootRounded = SIMD2<Double>(SIMD2<Float>(root))
      var output = ""
      output += "\(coefficients[0]) * \(rootRounded)^3 + "
      output += "\(coefficients[1]) * \(rootRounded)^2 + "
      output += "\(coefficients[2]) * \(rootRounded)^1 + "
      output += "\(coefficients[3]) = "
      
      let root0 = SIMD2<Double>(1, 0)
      let root1 = root
      let root2 = NCFMechanism.complexMultiply(root1, root1)
      let root3 = NCFMechanism.complexMultiply(root2, root1)
      
      var rhs: SIMD2<Double> = .zero
      rhs += coefficients[3] * root0
      rhs += coefficients[2] * root1
      rhs += coefficients[1] * root2
      rhs += coefficients[0] * root3
      print(output + "\(rhs)")
    }
  }
  
  @_transparent
  static func complexMultiply(
    _ lhs: SIMD2<Double>, _ rhs: SIMD2<Double>
  ) -> SIMD2<Double> {
    // (a + bi)(c + di) = (ac - bd) + (bc + ad)i
    let (a, b, c, d) = (lhs[0], lhs[1], rhs[0], rhs[1])
    return SIMD2(a * c - b * d, b * c + a * d)
  }
  
  // Source: https://en.wikipedia.org/wiki/Cubic_equation#General_cubic_formula
  static func solveCubicEquation(
    coefficients: SIMD4<Double>, debugResults: Bool = false
  ) -> (SIMD2<Double>, SIMD2<Double>, SIMD2<Double>) {
    let a = coefficients[0]
    let b = coefficients[1]
    let c = coefficients[2]
    let d = coefficients[3]
    
    let Δ0 = b * b - 3 * a * c
    let Δ1 = 2 * b * b * b - 9 * a * b * c + 27 * a * a * d
    if debugResults {
      print("Δ0: \(Δ0)")
      print("Δ1: \(Δ1)")
    }
    
    // The square root term may be negative, producing an imaginary number.
    let squareRootTerm = Δ1 * Δ1 - 4 * Δ0 * Δ0 * Δ0
    let squareRootMagnitude = squareRootTerm.magnitude.squareRoot()
    var cubeRootTerm = SIMD2<Double>(Δ1, 0)
    if squareRootTerm < 0 {
      cubeRootTerm[1] = squareRootMagnitude
    } else {
      cubeRootTerm[0] += squareRootMagnitude
    }
    cubeRootTerm /= 2
    if debugResults {
      print("cube root term: \(cubeRootTerm[0]) \(cubeRootTerm[1])")
    }
    
    // The cube root term is a complex number. We need to separate it into
    // magnitude and phase on the complex plane.
    var cubeRootMagnitude = (cubeRootTerm * cubeRootTerm).sum().squareRoot()
    let cubeRootDirection = cubeRootTerm / cubeRootMagnitude
    var cubeRootPhase = atan2(cubeRootDirection.y, cubeRootDirection.x)
    if debugResults {
      print("cube root: \(Double(Float(cubeRootMagnitude))) \(Double(Float(cubeRootPhase)))")
      print("cube root direction: \(Double(Float(cubeRootDirection.x))) \(Double(Float(cubeRootDirection.y)))")
    }
    
    // Form the first of three cube roots.
    cubeRootMagnitude = cbrt(cubeRootMagnitude)
    cubeRootPhase /= 3
    func createCubeRootDirection(phase: Double) -> SIMD2<Double> {
      let cubeRootDirection = SIMD2(cos(phase), sin(phase))
      let cubeRoot = cubeRootDirection * cubeRootMagnitude
      if debugResults {
        print("cube root:")
        print("- magnitude=\(Double(Float(cubeRootMagnitude))) phase=\(Double(Float(phase)))")
        print("- direction \(Double(Float(cubeRootDirection.x))) \(Double(Float(cubeRootDirection.y)))")
        print("- value: \(SIMD2<Double>(SIMD2<Float>(cubeRoot)))")
      }
      return cubeRoot
    }
    let cubeRoot0 = createCubeRootDirection(phase: cubeRootPhase)
    let cubeRoot1 = createCubeRootDirection(phase: cubeRootPhase + 2 * .pi / 3)
    let cubeRoot2 = createCubeRootDirection(phase: cubeRootPhase + 4 * .pi / 3)
    
    // Primitive roots of unity are complex numbers.
//    let root0 = SIMD2<Double>(2, 0) / 2
//    let root1 = SIMD2<Double>(-1, 1.73205080757) / 2
//    let root2 = SIMD2<Double>(-1, -1.73205080757) / 2
    
    func x(k: Int) -> SIMD2<Double> {
      let cubeRoot: SIMD2<Double> = (k == 0) ? cubeRoot0 : (k == 1 ? cubeRoot1 : cubeRoot2)
      var output: SIMD2<Double> = .zero
      output += SIMD2(b, 0)
      output += cubeRoot
      
      let conjugate = SIMD2(cubeRoot[0], -cubeRoot[1])
      let denominator = NCFMechanism.complexMultiply(cubeRoot, conjugate)
      let reciprocal = conjugate / denominator[0]
      output += Double(Δ0) * reciprocal
      
      output /= Double(-3 * a)
      return output
    }
    
//    @_transparent
//    func x(k: Int) -> SIMD2<Double> {
////      let unityRoot = (k == 0) ? root0 : (k == 1 ? root1 : root2)
////      let εC = NCFMechanism.complexMultiply(unityRoot, cubeRootDirection)
//      let εC = (k == 0) ? cubeRootDirection0 : (k == 1 ? cubeRootDirection1 : cubeRootDirection2)
//      let εC_conj = SIMD2(εC[0], -εC[1])
//      let fracDenom = NCFMechanism.complexMultiply(εC, εC_conj)
//
//      var x = b + εC + Δ0 * εC_conj / fracDenom.x
//      x /= -3 * a
//
//      if debugResults {
//        print("root: \(Double(Float(x[0]))) + \(Double(Float(x[1])))i")
//      }
////      // Throw away the imaginary part of the root.
////      return x[0]
//      return x
//    }
    
    return (x(k: 0), x(k: 1), x(k: 2))
  }
  
  // This is still buggy, even after multiple attempts to understand what is
  // going on. I give up.
  static func gaussianElimination(
    matrix: (SIMD3<Double>, SIMD3<Double>, SIMD3<Double>),
    eigenValues: [Double]
  ) -> [SIMD3<Double>] {
    var output: [SIMD3<Double>] = []
    withUnsafeTemporaryAllocation(of: SIMD3<Double>.self, capacity: 3) { B in
      for k in 0..<3 {
        let eigenValue = eigenValues[k]
        B[0] = matrix.0
        B[1] = matrix.1
        B[2] = matrix.2
        B[0].x -= eigenValue
        B[1].y -= eigenValue
        B[2].z -= eigenValue
        
        print("B original: \(B[0][0]) \(B[1][0]) \(B[2][0])")
        print("            \(B[0][1]) \(B[1][1]) \(B[2][1])")
        print("            \(B[0][2]) \(B[1][2]) \(B[2][2])")
        
        /*
        for i in 0..<3 {
          for j in (i &+ 1)..<3 {
//            if B[j][i].magnitude > B[i][i].magnitude {
            if B[i][j].magnitude > B[i][i].magnitude {
              for l in 0..<3 {
//                swap(&B[i][l], &B[j][l])
                let temp = B[l][i]
                B[l][i] = B[l][j]
                B[l][j] = temp
              }
            }
          }
          for j in (i &+ 1)..<3 {
//            let multiplier = B[j][i] / B[i][i]
            let multiplier = B[i][j] / B[i][i]
            for l in 0..<3 {
//              B[j][l] -= multiplier * B[i][l]
              B[l][j] -= multiplier * B[l][i]
            }
          }
        }
         */
        
        // Something better than GPT-4, sourced from:
        // https://www.geeksforgeeks.org/gaussian-elimination/
        for k in 0..<3 {
          var i_max = k
          var v_max = B[k][i_max]
          
          for i in (k + 1)..<3 {
            if B[k][i] > v_max {
              v_max = B[k][i]
              i_max = i
            }
          }
          if B[i_max][k].magnitude < .leastNormalMagnitude {
            fatalError("Matrix is singular.")
          }
          
          if i_max != k {
            for columnID in 0..<3 {
              var temp1 = B[columnID][i_max]
              var temp2 = B[columnID][k]
              swap(&temp1, &temp2)
              B[columnID][i_max] = temp1
              B[columnID][k] = temp2
            }
          }
          for i in (k + 1)..<3 {
            let f = B[k][i] / B[k][k]
            
            // We end the loop at <3, not <=3 as shown in the source. We aren't
            // using an augmented matrix.
            for j in (k + 1)..<3 {
              B[j][i] -= B[j][k] * f
            }
            B[k][i] = 0
          }
        }
        
        print("B eliminated: \(B[0][0]) \(B[1][0]) \(B[2][0])")
        print("              \(B[0][1]) \(B[1][1]) \(B[2][1])")
        print("              \(B[0][2]) \(B[1][2]) \(B[2][2])")
        
        var eigenVector: SIMD3<Double> = .zero
        var i = 2
        while i >= 0 {
//          eigenVector[i] = B[i][2] / B[i][i]
          eigenVector[i] = B[2][i]
//          for j in 0..<i {
//            B[j][2] -= B[j][i] * eigenVector[i]
//            B[2][j] -= B[i][j] * eigenVector[i]
          for j in (i + 1)..<3 {
            eigenVector[i] -= B[j][i] * eigenVector[j]
          }
          eigenVector[i] /= B[i][i]
          i &-= 1
        }
        
        let eigenVectorLength = (eigenVector * eigenVector).sum().squareRoot()
        output.append(eigenVector / eigenVectorLength)
      }
    }
    return output
  }
}

// Unit tests:
// - Get MM4ForceField to the point it can selectively generate parameters. ✅
//   - Disable torsions, hydrogen reductions, and bend-bend forces in the Swift
//     file for 'NCFPart'. ✅
//   - Verify that parameter generation time decreases and the parameters for
//     certain forces are removed. ✅
// - Get MM4ForceField to the point it can produce single-point energies.
//   - Don't worry about optimizing the 'MM4Force' objects to skip
//     initialization or GPU computation; just make them have zero effect.
// - Check the correctness of nonbonded forces w/ hydrogen reductions, making
//   vdW the first correctly functioning force reported on the README.
//   - Compare the instantaneous forces computed from TopologyMinimizer and
//     MM4ForceField without hydrogen reductions.
//   - Evaluate the equilibrium distance with TopologyMinimizer, predict how
//     much hydrogen reductions will shift it.
//   - Run the nonbonded force from MM4ForceField and verify the shift
//     matches TopologyMinimizer.
// - Create the first unit test: a single force evaluation on 'NCFMechanism'.
//   - Only embed vector literals for the 1st part, even in the 2-part system.
//   - Hard-code the expected values of 1 part vs. 2 parts. Create an assertion
//     that in the latter case, values are much greater.
//   - Hard-code the expected values for the 2-part system before and after
//     enabling hydrogen reductions.
// - Test how much the structure shifts when energy-minimized, just simulating
//   a single 'NCFPart'.
//   - The shift ought to be small, but nonzero, resulting in a quick test.
//   - Start with single-point forces, comparing to TopologyMinimizer.
//   - Get MM4ForceField to the point it can do energy minimizations.
//   - Analyze the difference between compiled and minimized structures. Also,
//     the difference between TopologyMinimizer (harmonic angle, no hydrogen
//     reduction) and MM4ForceField (sextic angle, hydrogen reduction).
//   - Measure execution time of the energy minimization, then add a unit test.
