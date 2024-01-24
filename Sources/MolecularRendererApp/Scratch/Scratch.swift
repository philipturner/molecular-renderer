// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  let xorGate = XORGate()
  
  var topologies: [Topology] = []
  for housingUnit in xorGate.housingUnits {
    topologies.append(housingUnit.topology)
  }
  for logicRod in xorGate.logicRods {
    topologies.append(logicRod.topology)
  }
  var atoms = topologies.flatMap(\.atoms)
  
  // TODO: Test the forward execution pass of two I/O pairs with MD simulations.
  // One pair outputs 0; another outputs 1. Finally, use RBD to simulate how
  // logic rods should move with each I/O pair and reversible clocking.
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = []
  paramsDesc.bonds = []
  var sceneParameters = try! MM4Parameters(descriptor: paramsDesc)
  for topology in topologies {
    paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = topology.bonds
    let parameters = try! MM4Parameters(descriptor: paramsDesc)
    sceneParameters.append(contentsOf: parameters)
  }
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.integrator = .multipleTimeStep
  forceFieldDesc.parameters = sceneParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = atoms.map(\.position)
  forceField.minimize()
  
  for i in atoms.indices {
    atoms[i].position = forceField.positions[i]
  }
  
  var animation: [[Entity]] = [atoms]
  for frameID in 0..<0 {
    if frameID % 10 == 0 {
      print("frame=\(frameID)")
    }
    forceField.simulate(time: 0.100)
    for i in atoms.indices {
      atoms[i].position = forceField.positions[i]
    }
    animation.append(atoms)
  }
  
  return animation
}
