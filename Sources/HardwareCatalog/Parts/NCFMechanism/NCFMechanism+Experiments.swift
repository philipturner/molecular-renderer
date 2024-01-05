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
  mutating func simulationExperiment1() {
    /*
     // Result of minimization with all forces activated:
     - part 0 center of mass delta: SIMD3<Float>(2.3841858e-05, -0.000230968, -5.7041645e-05)
     - part 1 center of mass delta: SIMD3<Float>(-7.677078e-05, -0.00022423267, 5.7518482e-05)
     
     // With only nonbonded force (the atoms will explode):
     - part 0 center of mass delta: SIMD3<Float>(0.0017161369, -0.0022693276, 0.011400461)
     - part 1 center of mass delta: SIMD3<Float>(-0.0023555756, -0.0018498898, -0.011299193)
     */
    
    print("before minimization:")
    var centersOfMass: [SIMD3<Float>] = []
    for i in self.parts.indices {
      let centerOfMass = self.parts[i].rigidBody.centerOfMass
      centersOfMass.append(centerOfMass)
      print("- part \(i) center of mass:", centerOfMass)
    }
    
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.rigidBodies = self.parts.map(\.rigidBody)
    descriptor.forces = [.bend, .stretch, .nonbonded]
    var minimizer = TopologyMinimizer(descriptor: descriptor)
    minimizer.minimize()
    
    print("after minimization:")
    for i in self.parts.indices {
      let range = self.atomRange(partID: i)
      minimizer.export(to: &self.parts[i].rigidBody, range: range)
      
      let centerOfMass = self.parts[i].rigidBody.centerOfMass
      let delta = centerOfMass - centersOfMass[i]
      print("- part \(i) center of mass delta:", delta)
    }
  }
}
