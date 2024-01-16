// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Automate all data collection from xTB and MM4, including charges (via
  // xtb/cpu0/charges).
  
  var topology = createTopology(carbonCount: 0)
  
  #if true
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = parameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = topology.atoms.map(\.position)
  
  print(forceField.energy.potential)
  for force in forceField.forces {
    print("-", force)
  }
  
  forceField.minimize()
  
  print(forceField.energy.potential)
  for force in forceField.forces {
    print("-", force)
  }
  
  for i in forceField.positions.indices {
    topology.atoms[i].position = forceField.positions[i]
  }
  #endif
  
  return topology.atoms
}

