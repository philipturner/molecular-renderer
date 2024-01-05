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
    descriptor.forces = [.bend, .stretch, .nonbonded]
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
      let mechanism = NCFMechanism(partCount: partCount)
      
      var descriptor = TopologyMinimizerDescriptor()
      descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
      descriptor.forces = [.bend, .stretch, .nonbonded]
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
      
      descriptor.forces = [.bend, .stretch]
      minimizer = TopologyMinimizer(descriptor: descriptor)
      print("- only bonded force active:")
      reportForce()
      
      descriptor.forces = [.nonbonded]
      minimizer = TopologyMinimizer(descriptor: descriptor)
      print("- only nonbonded force active:")
      reportForce()
    }
    
    /*
     // Results of experiment:
     system with part count 1:
     - all forces active:
       - rigid body 0:
         - net force: SIMD3<Float>(0.0005493164, 0.0010986328, 6.1035156e-05)
         - force on atom 0: SIMD3<Float>(-1157.2515, -667.2945, -499.7759)
         - force on atom 1: SIMD3<Float>(-20.46606, -183.67426, -1354.0088)
         - force on atom 2: SIMD3<Float>(-21.162086, -1357.0562, -128.89323)
         - force on atom 3: SIMD3<Float>(-82.86391, 1849.9432, 1048.8672)
         - force on atom 4: SIMD3<Float>(-167.34058, 71.08136, -1355.8549)
     - only bonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(-0.004760742, 0.004638672, 0.003112793)
         - force on atom 0: SIMD3<Float>(-1087.4297, -627.8282, -443.9415)
         - force on atom 1: SIMD3<Float>(0.0, -93.886696, -1311.1318)
         - force on atom 2: SIMD3<Float>(0.0, -1267.4403, 348.52588)
         - force on atom 3: SIMD3<Float>(-40.24363, 1908.2019, 1349.3049)
         - force on atom 4: SIMD3<Float>(-81.307915, 46.943203, -1311.1318)
     - only nonbonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(0.00033569336, 0.015563965, 0.00088500977)
         - force on atom 0: SIMD3<Float>(-69.82174, -39.46629, -55.834423)
         - force on atom 1: SIMD3<Float>(-20.46606, -89.78756, -42.876965)
         - force on atom 2: SIMD3<Float>(-21.162086, -89.61581, -477.41913)
         - force on atom 3: SIMD3<Float>(-42.620277, -58.258755, -300.4377)
         - force on atom 4: SIMD3<Float>(-86.03267, 24.138159, -44.722973)
     system with part count 2:
     - all forces active:
       - rigid body 0:
         - net force: SIMD3<Float>(290.6991, -20.726257, 1770.8032)
         - force on atom 0: SIMD3<Float>(-1157.2313, -667.29004, -499.7519)
         - force on atom 1: SIMD3<Float>(-20.44973, -183.6687, -1353.9756)
         - force on atom 2: SIMD3<Float>(-21.119957, -1357.0333, -128.82867)
         - force on atom 3: SIMD3<Float>(-82.75754, 1849.9849, 1049.0385)
         - force on atom 4: SIMD3<Float>(-167.32997, 71.08211, -1355.8375)
       - rigid body 1:
         - net force: SIMD3<Float>(-290.69885, 20.731384, -1770.8002)
         - force on atom 0: SIMD3<Float>(-1157.2268, -666.3958, -503.97913)
         - force on atom 1: SIMD3<Float>(-21.918335, -180.81378, -1328.2748)
         - force on atom 2: SIMD3<Float>(-21.389723, -1356.1787, -131.12527)
         - force on atom 3: SIMD3<Float>(-83.7353, 1852.8899, 1039.4835)
         - force on atom 4: SIMD3<Float>(-167.98189, 71.9882, -1333.6854)
     - only bonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(-0.004760742, 0.004638672, 0.003112793)
         - force on atom 0: SIMD3<Float>(-1087.4297, -627.8282, -443.9415)
         - force on atom 1: SIMD3<Float>(0.0, -93.886696, -1311.1318)
         - force on atom 2: SIMD3<Float>(0.0, -1267.4403, 348.52588)
         - force on atom 3: SIMD3<Float>(-40.24363, 1908.2019, 1349.3049)
         - force on atom 4: SIMD3<Float>(-81.307915, 46.943203, -1311.1318)
       - rigid body 1:
         - net force: SIMD3<Float>(-0.0010986328, -0.0154418945, -0.00091552734)
         - force on atom 0: SIMD3<Float>(-1087.4275, -627.82684, -443.9416)
         - force on atom 1: SIMD3<Float>(-0.00032536685, -93.886536, -1311.1318)
         - force on atom 2: SIMD3<Float>(-0.00032538548, -1267.4423, 348.5276)
         - force on atom 3: SIMD3<Float>(-40.2332, 1908.2021, 1349.298)
         - force on atom 4: SIMD3<Float>(-81.307724, 46.943027, -1311.1318)
     - only nonbonded force active:
       - rigid body 0:
         - net force: SIMD3<Float>(290.69653, -20.726868, 1770.7996)
         - force on atom 0: SIMD3<Float>(-69.801674, -39.461807, -55.810402)
         - force on atom 1: SIMD3<Float>(-20.44973, -89.78201, -42.843796)
         - force on atom 2: SIMD3<Float>(-21.119957, -89.5929, -477.35455)
         - force on atom 3: SIMD3<Float>(-42.513905, -58.217045, -300.26642)
         - force on atom 4: SIMD3<Float>(-86.02205, 24.138903, -44.70569)
       - rigid body 1:
         - net force: SIMD3<Float>(-290.69537, 20.727432, -1770.8007)
         - force on atom 0: SIMD3<Float>(-69.79922, -38.568943, -60.037518)
         - force on atom 1: SIMD3<Float>(-21.918009, -86.927246, -17.142914)
         - force on atom 2: SIMD3<Float>(-21.389397, -88.73647, -479.65286)
         - force on atom 3: SIMD3<Float>(-43.5021, -55.312233, -309.8145)
         - force on atom 4: SIMD3<Float>(-86.67417, 25.045172, -22.553635)
     */
  }
  
  // Compute the net force and torque on each rigid body in the 2-part system.
  // Also, query the linear velocity and angular velocity. They should be
  // either zero or NAN.
  // - linear velocity/acceleration, force, mass
  // - angular velocity/acceleration, torque, moment of inertia
  static func simulationExperiment3() {
    let mechanism = NCFMechanism(partCount: 2)
    
    var descriptor = TopologyMinimizerDescriptor()
    descriptor.rigidBodies = mechanism.parts.map(\.rigidBody)
    descriptor.forces = [.nonbonded]
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
       - linear acceleration: 0.01540666 -0.0010984159 0.09385024
       - force: 290.69846 -20.725311 1770.8004

       - angular velocity: nan | nan nan nan
       - angular acceleration: 0.021431314 | 0.99176 -0.12637231 0.021026772
       - torque: 5.5251355 | -0.2745581 0.9491093 -0.15430273
     - rigid body 1:
       - mass: 18868.363
       - center of mass: 4.529469 0.8710828 0.84871304
       - moment of inertia: 4049.4663 -782.0105 -5.1021576e-05
                            -782.0105 106424.83 -2.9206276e-06
                            -5.1021576e-05 -2.9206276e-06 109983.74

       - linear velocity: 0.0 0.0 0.0
       - linear acceleration: -0.015406634 0.0010985716 -0.09385019
       - force: -290.69797 20.728249 -1770.7994

       - angular velocity: nan | nan nan nan
       - angular acceleration: 0.019147305 | -0.98148817 -0.18939684 -0.028456891
       - torque: 6.13202 | -0.19123122 -0.9690017 -0.15641746
     */
  }
}
