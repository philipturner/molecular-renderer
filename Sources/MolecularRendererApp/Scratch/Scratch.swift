// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

// Test two-bit logic gates with full MD simulation. Verify that they work
// reliably at room temperature with the proposed actuation mechanism, at up
// to a 3 nm vdW cutoff. How long do they take to switch?
//
// This may require serializing long MD simulations to the disk for playback.
func createGeometry() -> [Entity] {
  var systemDesc = SystemDescriptor()
  systemDesc.patternA = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        // 2 or 6
        Origin { 6 * h }
        Plane { h }
        
        Origin { 1.5 * h2k }
        Plane { h2k }
        
        // 6 or 6
        Origin { 6 * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
  systemDesc.patternB = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        // 2 or 6
        Origin { 6 * h }
        Plane { h }
        
        Origin { 1.5 * h2k }
        Plane { h2k }
        
        // 6 or 6
        Origin { 6 * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
  systemDesc.patternC = { h, k, l in
    let h2k = h + 2 * k
    Volume {
      Concave {
        Origin { 2 * h }
        Plane { h }
        
        Origin { 0.5 * h2k }
        Plane { -h2k }
        
        Origin { 6 * h }
        Plane { -h }
      }
      Concave {
        Origin { 11 * h }
        Plane { h }
        
        Origin { 0.5 * h2k }
        Plane { -h2k }
        
        Origin { 5 * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
  
  var system = System(descriptor: systemDesc)
  system.passivate()
  system.minimizeSurfaces()
  
  // Initialize the rigid bodies with thermal velocities, then zero out the
  // drift in bulk momentum.
  let randomThermalVelocities = system.createRandomThermalVelocities()
  var topologies = system.getTopologies()
  for topologyID in topologies.indices {
    print()
    print("topologies[\(topologyID)]")
    let topology = topologies[topologyID]
    let velocities = randomThermalVelocities[topologyID]
    for i in 0..<3 {
      let atom = topology.atoms[i]
      let Z = atom.atomicNumber
      print("Z = \(Z) | velocities[\(i)] = \(velocities[i])")
    }
    for i in (velocities.count - 3)..<velocities.count {
      let atom = topology.atoms[i]
      let Z = atom.atomicNumber
      print("Z = \(Z) | velocities[\(i)] = \(velocities[i])")
    }
  }
  
  system.setAtomVelocities(randomThermalVelocities)
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.forces = []
  var rigidBodies = system.createRigidBodies(parametersDescriptor: paramsDesc)
  print()
  print("rigid bodies")
  for rigidBodyID in rigidBodies.indices {
    let rigidBody = rigidBodies[rigidBodyID]
    let linearMomentum = SIMD3<Float>(rigidBody.linearMomentum)
    print("rigidBodies[\(rigidBodyID)].linearMomentum = ", terminator: "")
    print(linearMomentum)
  }
  for rigidBodyID in rigidBodies.indices {
    let rigidBody = rigidBodies[rigidBodyID]
    let angularMomentum = SIMD3<Float>(rigidBody.angularMomentum)
    print("rigidBodies[\(rigidBodyID)].angularMomentum = ", terminator: "")
    print(angularMomentum)
  }
  
  for rigidBodyID in rigidBodies.indices {
    var rigidBody = rigidBodies[rigidBodyID]
    rigidBody.linearMomentum = .zero
    rigidBody.angularMomentum = .zero
    rigidBodies[rigidBodyID] = rigidBody
  }
  let rigidBodyAtomVelocities = rigidBodies.map(\.velocities)
  system.setAtomVelocities(rigidBodyAtomVelocities)
  
  let atomVelocities = system.getAtomVelocities()
  topologies = system.getTopologies()
  for topologyID in topologies.indices {
    print()
    print("topologies[\(topologyID)]")
    let topology = topologies[topologyID]
    let velocities = atomVelocities[topologyID]
    for i in 0..<3 {
      let atom = topology.atoms[i]
      let Z = atom.atomicNumber
      print("Z = \(Z) | velocities[\(i)] = \(velocities[i])")
    }
    for i in (velocities.count - 3)..<velocities.count {
      let atom = topology.atoms[i]
      let Z = atom.atomicNumber
      print("Z = \(Z) | velocities[\(i)] = \(velocities[i])")
    }
  }
  
  rigidBodies = system.createRigidBodies(parametersDescriptor: paramsDesc)
  print()
  print("rigid bodies")
  for rigidBodyID in rigidBodies.indices {
    let rigidBody = rigidBodies[rigidBodyID]
    let linearMomentum = SIMD3<Float>(rigidBody.linearMomentum)
    print("rigidBodies[\(rigidBodyID)].linearMomentum = ", terminator: "")
    print(linearMomentum)
  }
  for rigidBodyID in rigidBodies.indices {
    let rigidBody = rigidBodies[rigidBodyID]
    let angularMomentum = SIMD3<Float>(rigidBody.angularMomentum)
    print("rigidBodies[\(rigidBodyID)].angularMomentum = ", terminator: "")
    print(angularMomentum)
  }
  
  // TODO: Push this debugging code to GitHub before you delete it.
  
  return topologies.flatMap(\.atoms)
}
