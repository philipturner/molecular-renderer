// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

// This is a ~week-long experiment with rigid body dynamics. It may result in a
// faster alternative to MD that can produce low-latency, robust animation. This
// outcome would be a stopgap until the 'SimulationImport' library is finished.
//
// Objectives:
// - Investigate the maximum possible timestep with rigid body dynamics.
// - Recycle this experiment into a set of low-latency MM4 unit tests, covering
//   all of the basic functionality of an MVP.
// - Experiment with workflows that divide work into smaller chunks. Anticipate
//   and avoid burnout by alternating between 2 unrelated objectives.
// - Continue sharpening the ability to accomplish multiple tasks in the same
//   project, reducing the total time to solve all of them.
//
// Experiment:
// - Set up the NCFMechanism data structure. ✅
// - Adjust TopologyMinimizer to have the same ergonomic rigid body API as
//   MM4ForceField. ✅
// - Compare the instantaneous forces in TopologyMinimizer with a 1-part vs.
//   2-part system. ✅
// - Compute the net force and torque on each rigid body in the 2-part system. ✅
// - Set up a Verlet integrator. ✅
//   - Visualize an MD and rigid body dynamics trajectory side-by-side, both
//     with the same timestep. ✅
// - Study where the system breaks down in the limit of large time steps. ✅
//   - This particular system breaks down at ~100 fs time step. ✅
//   - Study viability of a variable time step that automatically detects
//     force explosions and recursively retries with a smaller timestep. ✅
//   - After correcting for a mistake in timestep reporting, I got further
//     evidence the stable timestep is ~80-160 fs. This is exciting news! The
//     stable timestep varies in an interesting way with the energy threshold:
//     - molecular dynamics ->  2 fs -> setup time: 29456.6 ms
//     -        0.1 yJ/atom -> failure
//     -        0.3 yJ/atom -> failure
//     -        1   yJ/atom -> failure
//     -        3   yJ/atom -> 60 fs -> setup time: 12618.0 ms
//     -       10   yJ/atom -> 80 fs -> setup time: 14042.8 ms
//     -       30   yJ/atom -> 80 fs -> setup time: 17919.8 ms
//     -      100   yJ/atom -> 80 fs -> setup time: 15441.0 ms
//     -      300   yJ/atom -> 80 fs -> setup time: 15690.9 ms
//   - Also, note that the rigid body dynamics implementation is significantly
//     underoptimized. It performs better with larger systems that can amortize
//     the overhead of GPU communication. Plus, we can vectorize and parallelize
//     the CPU-side code.
//     - The most important insight is not the absolute speedup measured, but
//       the increase in timestep measured.
//     - Second, the issues that arise with conservation of momentum with rigid
//       body mechanics. We need to look into why we needed to store the
//       momenta separately from the atom velocities. In addition, why the code
//       reported the momenta as drifting with rigid body dynamics, but not
//       with molecular dynamics. It is obviously very messy code, and we'll
//       need to start over from scratch to make more progress.
//     - Third, base64 encoding can do a lot of useful things. I might even
//       look into base64-encoding the forces from TopologyMinimizer and pasting
//       into the MM4 test suite. That can recycle the existing function
//       'encodeAtoms' with no changes, or the API can be revised to something
//       with more general function names (e.g. encodeFloat4).
//   - Running the benchmark again with 10x more atoms and 1/10 the time:
//
// Unit tests:
// - Get MM4ForceField to the point it can selectively generate parameters.
//   - Disable torsions, hydrogen reductions, and bend-bend forces in the Swift
//     file for 'NCFPart'.
//   - Verify that parameter generation time decreases and the parameters for
//     certain forces are removed.
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

func createNCFMechanism() -> [[Entity]] {
//  let mechanism = NCFMechanism(partCount: 2)
//  return NCFMechanism.createEntities(
//    mechanism.parts.map(\.rigidBody))
  
  return NCFMechanism.simulationExperiment4()
}

extension NCFMechanism {
  // Run a few iterations of Verlet integration, then export the results to
  // an array of animation frames. Do not compare to MD simulation yet.
  @discardableResult
  static func simulationExperiment4() -> [[Entity]] {
    let rigidBodyDynamics = true
    
    var mechanism = NCFMechanism(
      partCount: 4, forces:
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
    let thresholdInYJ = Double(300) * Double(atomCount)
    let thresholdInZJ = thresholdInYJ / 1000
    
    let potentialBase = minimizer.createPotentialEnergy()
    var output: [[Entity]] = []
    var maxJ: Int = 1
    var originalSavePoint: (energy: Double, mechanism: NCFMechanism)?
    var savePoint: (energy: Double, mechanism: NCFMechanism)?
    var timeSinceSave = 0
    
    var i = 0
    let timeStep: Double = 0.160
    while i < 700 {
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
      if let originalSavePoint,
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
