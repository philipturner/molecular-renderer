// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// WARNING: The renderer is currently in 'MRSceneSize.extreme'. It will not
// render any animations.
func createGeometry() -> [Entity] {
  // Create the scene.
  var housing = Housing()
  
  // TODO: Save the repo state after taking the image.
  if true {
    var paramsDesc = MM4ParametersDescriptor()
    paramsDesc.atomicNumbers = housing.topology.atoms.map(\.atomicNumber)
    paramsDesc.bonds = housing.topology.bonds
    var parameters = try! MM4Parameters(descriptor: paramsDesc)
    for atomID in housing.topology.atoms.indices {
      let centerType = parameters.atoms.centerTypes[atomID]
      if centerType == .quaternary {
        parameters.atoms.masses[atomID] = 0
      }
    }
    
    var forceFieldDesc = MM4ForceFieldDescriptor()
    forceFieldDesc.parameters = parameters
    let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
    forceField.positions = housing.topology.atoms.map(\.position)
    forceField.minimize()
    
    for atomID in housing.topology.atoms.indices {
      var atom = housing.topology.atoms[atomID]
      let position = forceField.positions[atomID]
      atom.position = position
      housing.topology.atoms[atomID] = atom
    }
  }
  
  
  let rods = Rods()
  
  // Create the atoms.
  var atoms: [Entity] = []
  atoms += housing.topology.atoms
    .filter {
    var normal = SIMD3<Float>(-1, 1, 1)
    normal /= (normal * normal).squareRoot()
    return ($0.position * normal).sum() < 7
  }
  for rod in rods.rods {
    atoms += rod.topology.atoms
  }
  
  // Center the scene at the origin.
  var centerOfMass: SIMD3<Float> = .zero
  for atomID in atoms.indices {
    centerOfMass += atoms[atomID].position
  }
  centerOfMass /= Float(atoms.count)
  for atomID in atoms.indices {
    atoms[atomID].position -= centerOfMass
  }
  
  // Return the atoms.
  return atoms
}
