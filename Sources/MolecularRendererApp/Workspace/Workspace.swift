import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Test whether it works in a
// constrained MD simulation.

func createGeometry() -> [MM4RigidBody] {
  // TODO: Finish the process of serializing the half adder's housing
  // to minimize load time.
  //
  // TODO: Repeat the process to accelerate drive system load time. Serialize
  // the flywheel and connecting rod as source literals. Then, you can analyze
  // the rigid body kinetic energies with fast feedback loops.
  
  let inputUnit = InputUnit()
  let intermediateUnit = IntermediateUnit()
  
  var housingDesc = LogicHousingDescriptor()
  housingDesc.dimensions = SIMD3(22, 17, 14)
  housingDesc.patterns.append(contentsOf: inputUnit.holePatterns)
  housingDesc.patterns.append(contentsOf: intermediateUnit.holePatterns)
  housingDesc.surfaceAtoms = HalfAdder.serializedString
  let housing = LogicHousing(descriptor: housingDesc)
  
  return [housing.rigidBody]
}
