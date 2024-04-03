import Foundation
import HDL
import MM4
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  var rigidBodies: [MM4RigidBody] = []
  
  let housing = Housing()
  rigidBodies.append(housing.rigidBody)
  
  var flywheel = Flywheel()
  let latticeConstant = Constant(.square) { .elemental(.carbon) }
  flywheel.rigidBody.centerOfMass.x += Double(10 * latticeConstant)
  flywheel.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
  flywheel.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
  rigidBodies.append(flywheel.rigidBody)
  
  var piston = Piston()
  piston.rigidBody.centerOfMass.x += Double(27 * latticeConstant)
  piston.rigidBody.centerOfMass.y += Double(10 * latticeConstant)
  piston.rigidBody.centerOfMass.z += Double(10.3 * latticeConstant)
  rigidBodies.append(piston.rigidBody)
  
  var forceFieldParameters = housing.rigidBody.parameters
  forceFieldParameters.append(contentsOf: flywheel.rigidBody.parameters)
  forceFieldParameters.append(contentsOf: piston.rigidBody.parameters)
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = forceFieldParameters
  forceFieldDesc.cutoffDistance = 2
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rigidBodies.flatMap(\.positions)
  forceField.minimize(tolerance: 10)
  
  var output: [Entity] = []
  for atomID in forceFieldParameters.atoms.indices {
    let atomicNumber = forceFieldParameters.atoms.atomicNumbers[atomID]
    let position = forceField.positions[atomID]
    let entity = Entity(storage: SIMD4(position, Float(atomicNumber)))
    output.append(entity)
  }
  
  return output
}
