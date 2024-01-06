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
