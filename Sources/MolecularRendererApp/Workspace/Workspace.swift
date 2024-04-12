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
  // TODO: Create the patterns for the logic rods.
  // TODO: Final optimization - shrink the cell footprint from 6.25 -> 6.00
  
  let halfAdder = HalfAdder()
  
  var rods: [Rod] = []
  rods.append(contentsOf: halfAdder.inputUnit.rods)
  rods.append(contentsOf: halfAdder.intermediateUnit.rods)
  return rods.map(\.rigidBody)
}
