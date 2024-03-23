// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test whether switches with sideways knobs work correctly. Test every
// possible permutation of touching knobs and approach directions.
//
// Then, test whether extremely long rods work correctly.
//
// Notes:
// - Save each test to 'rod-logic', in a distinct set of labeled files. Then,
//   overwrite the contents and proceed with the next test.
// - Run each setup with MD at room temperature.
func createGeometry() -> [Entity] {
  var system = System()
  system.alignParts()
  system.minimize()
  system.equilibriate(temperature: 298)
  
  // Conserve the thermal kinetic state associated with the thermal potential
  // state above. Set each rigid body's bulk momentum to the desired value. Use
  // the current inertial eigenbasis, as it shifts with thermal potential state.
  for i in system.rigidBodies.indices {
    print(system.rigidBodies[i].linearMomentum, system.rigidBodies[i].angularMomentum)
  }
  
  var atoms: [Entity] = []
  for rigidBody in system.rigidBodies {
    for atomID in rigidBody.parameters.atoms.indices {
      let atomicNumber = rigidBody.parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let storage = SIMD4(position, Float(atomicNumber))
      let entity = Entity(storage: storage)
      atoms.append(entity)
    }
  }
  return atoms
}
