import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms, and serialize the atoms as a
// base64 string. Place the adder somewhere in the scene. Also, design the
// drive wall that actuates the rods.
// - Lay out all of the housing and drive walls, before adding any patterns to
//   the logic rods.
// - Try just serializing the surface atoms. Erase the bond topology and move
//   the serialized atoms to the end of the list.
//
// Extract each logic rod, remove the hydrogens on one side, and place the
// finished products on the silicon surface. If we can compile a build
// sequence for one, compiling sequences for the rest should be trivial.

func createGeometry() -> [MM4RigidBody] {
  // TODO:
  // - Create 'HalfAdderUnit', which lays out all of the logic rods.
  // - Create the associated housing and drive wall objects. Find a good way to
  //   set up the data transfer from HalfAdderUnit -> LogicHousingDescriptor.
  // - Create the patterns for the logic rods, once you know the directions
  //   they will move. TODO: What if I can simplify the knob / <s>dopant</s>
  //   [NOT YET] placement procedure? Using parametric methods to locate an
  //   integer multiple of the lattice constant.
  
  let halfAdder = HalfAdder()
  
  return halfAdder.unit.rods.map(\.rigidBody)
}
