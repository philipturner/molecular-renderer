import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Test that each clocking stage
// works in a molecular dynamics simulation. Place the adder in the scene.
//
// Extract each logic rod, remove the hydrogens on one side, and arrange the
// finished products on the silicon surface. Compile a complete build sequence
// for every rod.

func createGeometry() -> [MM4RigidBody] {
  // TODO: Final optimization - shrink the cell footprint from 6.25 -> 6.00
  
  let halfAdder = HalfAdder()
  var rods: [Rod] = []
  rods.append(halfAdder.inputUnit.operandA[1])
  rods.append(halfAdder.intermediateUnit.generate[0])
  
  var rigidBodies = rods.map { $0.rigidBody }
  rigidBodies[1].centerOfMass.y += 0.50 * 0.3567
  var forceFieldParameters = rigidBodies[0].parameters
  forceFieldParameters.append(contentsOf: rigidBodies[1].parameters)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.parameters = forceFieldParameters
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = rigidBodies.flatMap(\.positions)
  
  // halfAdder.inputUnit.operandA[0]
  // halfAdder.intermediateUnit.generate[0]
  //
  // 0.00 cells
  // 19750.516845703125
  // 19750.516357421875
  // 19750.517333984375
  //
  // 0.25 cells
  // 19724.39794921875
  // 19724.39794921875
  // 19724.398193359375
  //
  // 0.50 cells
  // 19780.488525390625
  // 19780.489013671875
  // 19780.48828125
  
  // halfAdder.inputUnit.operandA[1]
  // halfAdder.intermediateUnit.generate[0]
  //
  // 0.00 cells
  // 19758.978271484375
  // 19758.97900390625
  // 19758.97900390625
  //
  // 0.25 cells
  // 19691.806884765625
  // 19691.80712890625
  // 19691.806396484375
  //
  // 0.50 cells
  // 20009.18359375
  // 20009.18212890625
  // 20009.182373046875
  print(forceField.energy.potential)
  
  exit(0)
}
