import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  var output: [Entity] = []
  
  // TODO: Shrink everything by a factor of 1.5, in every spatial dimension.
  // Except, keep the flywheel and piston z-thickness the same.
  
  let housing = Housing()
  for atomID in housing.rigidBody.parameters.atoms.indices {
    let atomicNumber = housing.rigidBody.parameters.atoms.atomicNumbers[atomID]
    let position = housing.rigidBody.positions[atomID]
    let storage = SIMD4(position, Float(atomicNumber))
    output.append(Entity(storage: storage))
  }
  
  var flywheel = Flywheel()
  let latticeConstant = Constant(.square) { .elemental(.carbon) }
  flywheel.rigidBody.centerOfMass.x += Double(15 * latticeConstant)
  flywheel.rigidBody.centerOfMass.y += Double(15 * latticeConstant)
  flywheel.rigidBody.centerOfMass.z += Double(14.5 * latticeConstant)
  for atomID in flywheel.rigidBody.parameters.atoms.indices {
    let atomicNumber = flywheel.rigidBody.parameters.atoms.atomicNumbers[atomID]
    let position = flywheel.rigidBody.positions[atomID]
    let storage = SIMD4(position, Float(atomicNumber))
    output.append(Entity(storage: storage))
  }
  
  var piston = Piston()
  piston.rigidBody.centerOfMass.x += Double(40 * latticeConstant)
  piston.rigidBody.centerOfMass.y += Double(15 * latticeConstant)
  piston.rigidBody.centerOfMass.z += Double(14.5 * latticeConstant)
  for atomID in piston.rigidBody.parameters.atoms.indices {
    let atomicNumber = piston.rigidBody.parameters.atoms.atomicNumbers[atomID]
    let position = piston.rigidBody.positions[atomID]
    let storage = SIMD4(position, Float(atomicNumber))
    output.append(Entity(storage: storage))
  }
  
  return output
}
