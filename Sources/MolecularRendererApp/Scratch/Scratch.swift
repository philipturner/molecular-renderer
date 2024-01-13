// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createNanoRobot() -> [[Entity]] {
  var buildSite = RobotBuildSite(video: .version1)
  for i in buildSite.rigidBodies.indices {
    buildSite.rigidBodies[i].centerOfMass.y -= 1
  }
  func createEntities() -> [Entity] {
    let rigidBodies = buildSite.rigidBodies
    return rigidBodies.flatMap { rigidBody in
      rigidBody.parameters.atoms.indices.map { i in
        let element = Float(rigidBody.parameters.atoms.atomicNumbers[i])
        let position = rigidBody.positions[i]
        return Entity(storage: SIMD4(position, element))
      }
    }
  }
  
  return [createEntities()]
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
//      paramsDesc.hydrogenMassScale = 1
      let parameters = try! MM4Parameters(descriptor: paramsDesc)
//      for i in parameters.atoms.indices {
//        parameters.atoms.parameters[i].hydrogenReductionFactor = 0.9999
//      }
      
      var rigidBodyDesc = MM4RigidBodyDescriptor()
      rigidBodyDesc.parameters = parameters
      rigidBodyDesc.positions = topology.atoms.map(\.position)
      var rigidBody = try! MM4RigidBody(descriptor: rigidBodyDesc)
      
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
    _read {
      yield [plate, molecule]
    }
    _modify {
      var value = [plate, molecule]
      yield &value
      plate = value[0]
      molecule = value[1]
    }
  }
}
