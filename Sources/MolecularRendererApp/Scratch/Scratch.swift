// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [Entity] {
  let buildSite = RobotBuildSite(video: .version1)
  let rigidBodies = buildSite.rigidBodies
  
  // Try exerting an external force on an isolated molecule with MM4ForceField.
  // Log the actual and expected rigid body CoM + momentum to the console.
  //
  // Next, run an MD simulation of this scene, using both the old
  // TopologyMinimizer and the new MM4ForceField. Compare results visually after
  // a few ps, and compare energy drift over ~1 ns time span. Save the results
  // to the GitHub gist for debugging MM4 minimization performance.
  return rigidBodies.flatMap { rigidBody in
    rigidBody.parameters.atoms.indices.map { i in
      let element = Float(rigidBody.parameters.atoms.atomicNumbers[i])
      let position = rigidBody.positions[i]
      return Entity(storage: SIMD4(position, element))
    }
  }
}

struct RobotBuildSite {
  var plate: MM4RigidBody
  var molecule: MM4RigidBody
  
  init(video: RobotVideo) {
    var plate: RobotBuildPlate
    var molecule: RobotBuildMolecule
    
    if video == .version1 {
      plate = RobotBuildPlate(video: .version1)
      molecule = RobotBuildMolecule(video: .version1)
    } else {
      plate = RobotBuildPlate(video: .version2)
      molecule = RobotBuildMolecule(video: .version2)
    }
    
    // Creates a rigid body centered at the world origin.
    func createRigidBody(_ topology: Topology) -> MM4RigidBody {
      var paramsDesc = MM4ParametersDescriptor()
      paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
      paramsDesc.bonds = topology.bonds
      let parameters = try! MM4Parameters(descriptor: paramsDesc)
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = parameters
      rigidBodyDesc.positions = topology.atoms.map(\.position)
      var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
      print()
      print("rigid body:")
      print("- atom count:", rigidBody.parameters.atoms.count)
      print("- moment of inertia:", rigidBody.momentOfInertia)
      print("- principal axes:", rigidBody.principalAxes)
      
      rigidBody.centerOfMass = .zero
      return rigidBody
    }
    self.plate = createRigidBody(plate.topology)
    self.molecule = createRigidBody(molecule.topology)
    
    if video == .version1 {
      self.molecule.centerOfMass += SIMD3(0, 0.850, 0)
    } else {
      
    }
  }
  
  var rigidBodies: [MM4RigidBody] {
    get {
      [plate, molecule]
    }
  }
}
