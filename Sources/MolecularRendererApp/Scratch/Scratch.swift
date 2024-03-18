// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test two-bit logic gates with full MD simulation. Verify that they work
// reliably at room temperature with the proposed actuation mechanism, at up
// to a 3 nm vdW cutoff. How long do they take to switch?
//
// This may require serializing long MD simulations to the disk for playback.
func createGeometry() -> [[Entity]] {
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
  
  var topologies: [Topology] = []
  topologies.append(system.housing.topology)
  topologies.append(system.inputDriveWall.topology)
  topologies.append(system.outputDriveWall.topology)
  topologies.append(system.rodA.topology)
  topologies.append(system.rodB.topology)
  topologies.append(system.rodC.topology)
  
  var emptyParamsDesc = MM4ParametersDescriptor()
  emptyParamsDesc.atomicNumbers = []
  emptyParamsDesc.bonds = []
  var systemParameters = try! MM4Parameters(descriptor: emptyParamsDesc)
  
  for topologyID in topologies.indices {
    let topology = topologies[topologyID]
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    var partParameters = try! MM4Parameters(descriptor: paramsDesc)
    
    // Don't let the bulk atoms move during the minimization.
    for atomID in topology.atoms.indices {
      let centerType = partParameters.atoms.centerTypes[atomID]
      if centerType == .quaternary {
        partParameters.atoms.masses[atomID] = 0
      }
    }
    systemParameters.append(contentsOf: partParameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.cutoffDistance = 1 // not simulating dynamics yet
  forceFieldDesc.parameters = systemParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  
  var atoms = topologies.flatMap(\.atoms)
  forceField.positions = atoms.map(\.position)
  forceField.minimize()
  for atomID in atoms.indices {
    var atom = atoms[atomID]
    atom.position = forceField.positions[atomID]
    atoms[atomID] = atom
  }
  
  var atomCursor: Int = 0
  for topologyID in topologies.indices {
    var topology = topologies[topologyID]
    for atomID in topology.atoms.indices {
      let atom = atoms[atomCursor]
      topology.atoms[atomID] = atom
      atomCursor += 1
    }
    topologies[topologyID] = topology
  }
  
  var rigidBodies: [MM4RigidBody] = []
  for topologyID in topologies.indices {
    let topology = topologies[topologyID]
    
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    paramsDesc.forces = [.nonbonded]
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    
    var rigidBodyDesc = MM4RigidBodyDescriptor()
    rigidBodyDesc.parameters = parameters
    rigidBodyDesc.positions = topology.atoms.map(\.position)
    let rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
    rigidBodies.append(rigidBody)
  }
  
  var frames: [[Entity]] = []
  rigidBodies[2].centerOfMass.y += 2.2
  do {
    var fire = FIRE()
    fire.anchors = [0, 1, 2]
    fire.rigidBodies = rigidBodies
    let result = fire.minimize()
    
    rigidBodies = fire.rigidBodies
    frames += result.frames
  }
  
  rigidBodies[2].centerOfMass.y += -2.2
  rigidBodies[5].centerOfMass.x += -0.4
  do {
    var fire = FIRE()
    fire.anchors = [0, 1, 2, 3, 4]
    fire.rigidBodies = rigidBodies
    let result = fire.minimize()
    
    rigidBodies = fire.rigidBodies
    frames += result.frames
  }
  
  return frames
}

