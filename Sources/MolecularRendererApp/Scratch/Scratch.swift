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
  let rods = Rods()
  
  // TODO: Get all the necessary rods present and sorted, before patterning
  // any of them.
  
  // Create the atoms.
  var atoms: [Entity] = []
  for rod in rods.allRods {
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
