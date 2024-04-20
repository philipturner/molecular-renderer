import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  let cla = CLA()
  let rigidBodies = cla.rods.map(\.rigidBody)
  
  var atoms: [Entity] = []
  for rigidBody in rigidBodies {
    let parameters = rigidBody.parameters
    for atomID in parameters.atoms.indices {
      let atomicNumber = parameters.atoms.atomicNumbers[atomID]
      let position = rigidBody.positions[atomID]
      let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
      atoms.append(entity)
    }
  }
  
  let lattice = CLAHousing.createLattice(rods: cla.rods)
  for atom in lattice.atoms {
    var copy = atom
    copy.position -= SIMD3(0, 0, 18) * 0.3567
    atoms.append(copy)
  }
  
  return atoms
}
