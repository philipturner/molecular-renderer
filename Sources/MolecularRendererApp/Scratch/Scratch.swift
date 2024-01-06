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
// - Set up a Verlet integrator.
//   - Visualize an MD and rigid body dynamics trajectory side-by-side, both
//     with the same timestep.
// - Study where the system breaks down in the limit of large time steps.
//   - Study viability of a variable time step that automatically detects
//     force explosions and recursively retries with a smaller timestep.
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
    var mechanism = NCFMechanism(partCount: 2, forces: [.nonbonded])
    
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
    var minimizer = TopologyMinimizer(descriptor: descriptor)
    
    var output: [[Entity]] = []
    for i in 0..<2 {
      if i > 0 {
        // Simulate evolution for one timestep.
        for partID in mechanism.parts.indices {
          mechanism.parts[partID].rigidBody.centerOfMass.x += 1
        }
        
        // Update the simulator so it can compute forces for the next timestep.
        var positions: [SIMD3<Float>] = []
        for partID in mechanism.parts.indices {
          positions += mechanism.parts[partID].rigidBody.positions
        }
        minimizer.setPositions(positions)
      }
      
      output.append(Self.createEntities(mechanism.parts.map(\.rigidBody)))
    }
    return output
  }
}

extension NCFMechanism {
  // Evolve the system for a single time step, using Verlet integration.
  mutating func evolve(
    timeStep: Double,
    start: Bool,
    end: Bool,
    evaluateForces: () -> [SIMD3<Float>]
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
      let forces = evaluateForces()
      _evolve(
        velocityTimeStep: 0.5 * timeStep,
        positionTimeStep: 1.0 * timeStep,
        forces: forces)
    } else {
      let forces = evaluateForces()
      _evolve(
        velocityTimeStep: 1.0 * timeStep,
        positionTimeStep: 1.0 * timeStep,
        forces: forces)
    }
    
    if end {
      let forces = evaluateForces()
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
    for i in parts.indices {
      print("rigid body \(i):")
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
      var linearVelocity = rigidBody.linearVelocity
      var angularVelocity = rigidBody.angularVelocity
      print("- before:")
      print("  - center of mass: \(centerOfMass.x) \(centerOfMass.y) \(centerOfMass.z)")
      print("  - linear velocity: \(linearVelocity.x) \(linearVelocity.y) \(linearVelocity.z)")
      print("  - angular velocity: \(repr(angularVelocity))")
      
      linearVelocity += Float(velocityTimeStep) * linearAcceleration
      angularVelocity += Float(velocityTimeStep) * angularAcceleration
      rigidBody.linearVelocity = linearVelocity
      rigidBody.angularVelocity = angularVelocity
      
      // Update atom positions according to bulk velocity.
      guard positionTimeStep > 0 else {
        continue
      }
      let linearDisplacement = Float(positionTimeStep) * linearVelocity
      let angularDisplacement = Float(positionTimeStep) * angularVelocity
      let angularDisplacementQ = vector_to_quaternion(angularDisplacement)
      let rotation = (
        angularDisplacementQ.act(on: SIMD3<Float>(1, 0, 0)),
        angularDisplacementQ.act(on: SIMD3<Float>(0, 1, 0)),
        angularDisplacementQ.act(on: SIMD3<Float>(0, 0, 1)))
      print("- after:")
      print("  - center of mass: \(centerOfMass.x + linearDisplacement.x) \(centerOfMass.y + linearDisplacement.y) \(centerOfMass.z + linearDisplacement.z)")
      print("  - linear velocity: \(linearVelocity.x) \(linearVelocity.y) \(linearVelocity.z)")
      print("  - angular velocity: \(repr(angularVelocity))")
      
      let newPositions = rigidBody.positions.map { p in
        // An improved version of this would operate directly on the vectorized
        // atom positions and velocities.
        var r = p - centerOfMass
        r = rotation.0 * r.x + rotation.1 * r.y + rotation.2 * r.z
        return centerOfMass + linearDisplacement + r
      }
      rigidBody.setPositions(newPositions)
    }
  }
}

