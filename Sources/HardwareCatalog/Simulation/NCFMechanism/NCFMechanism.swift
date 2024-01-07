//
//  NCFMechanism.swift
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

struct NCFMechanism {
  var parts: [NCFPart] = []
  var linearVelocities: [SIMD3<Double>] = []
  var angularVelocities: [SIMD3<Double>] = []
  
  init(
    partCount: Int,
    forces: MM4ForceOptions = [.bend, .stretch, .nonbonded]
  ) {
    let compiledPart = NCFPart(forces: forces)
    for i in 0..<partCount {
      var part = compiledPart
      
      // Spacing for consecutive parts in the mechanism:
      /*
       rigidBody.centerOfMass.x += Float(i) * 0.5
       rigidBody.centerOfMass.z += Float(i) * 0.72
       */
      //
      // 0.72 was the equilibrium Z spacing measured in TopologyMinimizer
      // without hydrogen reductions. It was derived through trial and error,
      // observing how much motion occurred in the MD simulation when objects
      // started at a specific separation. I'm not sure how much this number
      // shifts due to nearby parts that aren't immediate neighbors.
      // - This is spacing between center of mass of rigid bodies.
      // - This is not the same as spacing between touching surfaces.
      // - Potentially a simpler, more direct method to quantify vdW separation.
      //   - Relative distances are the same regardless of whether this number
      //     or the average distance between hydrogen atoms is used.
      //   - Center of mass separation is drastically simpler to compute,
      //     consuming less time when writing the code.
      //
      // 0.5 was a good X spacing to get interesting motion. The parts start
      // out with the NCF magnets (corrugations in the upper and lower faces)
      // out of alignment. Nonbonded forces bring them into alignment, raising
      // the temperature to ~10K (ignoring quantum effects and assuming
      // classical behavior regarding equipartition of thermal kinetic energy).
      //
      // > NOTE: The above comment is good practice. Explaining the meaning
      //   behind certain raw numbers, when reasonable, can make the code easier
      //   to understand. It can also help you form connections between ideas
      //   and make progress when you're stumped.
      //
      // An image was taken to illustrate this spacing. At the time of writing,
      // it was located at 'HardwareCatalog/NCFMechanism/NCFMechanism_Image1'.
      let spacing: SIMD3<Float> = [0.5, 0, 0.72]
      part.rigidBody.centerOfMass += Float(i) * spacing
      parts.append(part)
    }
  }
  
  // Acquire the range of atoms that a part occupies in a simulator.
  func atomRange(partID: Int) -> Range<Int> {
    guard parts.indices.contains(partID) else {
      fatalError("Invalid part ID: \(partID)")
    }
    
    var prefixSum: [Int] = []
    var accumulator = 0
    prefixSum.append(accumulator)
    
    for i in parts.indices {
      let atomCount = parts[i].rigidBody.parameters.atoms.count
      accumulator += atomCount
      prefixSum.append(accumulator)
    }
    
    return prefixSum[partID]..<prefixSum[partID + 1]
  }
}

extension NCFMechanism {
  func reportState(forces systemForces: [SIMD3<Float>]) {
    print("system state, summarized by bulk properties:")
    for i in self.parts.indices {
      let rigidBody = self.parts[i].rigidBody
      print("- rigid body \(i):")
      
      let mass = rigidBody.mass
      let centerOfMass = rigidBody.centerOfMass
      let I = rigidBody.momentOfInertia
      print("  - mass: \(mass)")
      print("  - center of mass: \(centerOfMass.x) \(centerOfMass.y) \(centerOfMass.z)")
      print("  - moment of inertia: \(I.0.x) \(I.1.x) \(I.2.x)")
      print("                       \(I.0.y) \(I.1.y) \(I.2.y)")
      print("                       \(I.0.z) \(I.1.z) \(I.2.z)")
      
      let atomRange = self.atomRange(partID: i)
      let atomForces = Array(systemForces[atomRange])
      let atomTorques = zip(rigidBody.positions, atomForces).map { p, F in
        let r = p - centerOfMass
        return cross_platform_cross(r, F)
      }
      
      var forceAccumulator: SIMD3<Double> = .zero
      var torqueAccumulator: SIMD3<Double> = .zero
      for i in rigidBody.parameters.atoms.indices {
        forceAccumulator += SIMD3<Double>(atomForces[i])
        torqueAccumulator += SIMD3<Double>(atomTorques[i])
      }
      let force = SIMD3<Float>(forceAccumulator)
      let torque = SIMD3<Float>(torqueAccumulator)
      
      // p = m v -> v = p / m
      // L = I w -> w = I^-1 L
      //
      // F = m a -> a = F / m
      // T = I a -> a = I^-1 T
      let linearVelocity = rigidBody.linearVelocity
      let angularVelocity = rigidBody.angularVelocity
      
      let linearAcceleration = force / mass
      let inverseI = cross_platform_inverse3x3(I)
      let angularAcceleration =
      inverseI.0 * torque.x + inverseI.1 * torque.y + inverseI.2 * torque.z
      
      func repr(_ vector: SIMD3<Float>) -> String {
        let angle = (vector * vector).sum().squareRoot()
        let axis = vector / angle
        return "\(angle) | \(axis.x) \(axis.y) \(axis.z)"
      }
      
      print()
      print("  - linear velocity: \(linearVelocity.x) \(linearVelocity.y) \(linearVelocity.z)")
      print("  - linear acceleration: \(linearAcceleration.x) \(linearAcceleration.y) \(linearAcceleration.z)")
      print("  - force: \(force.x) \(force.y) \(force.z)")
      
      print()
      print("  - angular velocity: \(repr(angularVelocity))")
      print("  - angular acceleration: \(repr(angularAcceleration))")
      print("  - torque: \(repr(torque))")
    }
  }
}
