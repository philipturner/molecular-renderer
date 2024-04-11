import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Goal: Animate a build sequence for a small logic rod.

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms, and serialize the atoms as a
// base64 string. Place the adder somewhere in the scene. Also, design the
// drive wall that actuates the rods.
// - Lay out all of the housing and drive walls, before adding any patterns to
//   the logic rods.
//
// Extract each logic rod, remove the hydrogens on one side, and place the
// finished products on the silicon surface. If we can compile a build
// sequence for one, compiling sequences for the rest should be trivial.

// Drafting the housing here. Drive walls might need their own type object.
func createGeometry() -> [MM4RigidBody] {
  // Design a housing object that accepts some rod positions, then creates the
  // appropriate holes automatically.
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 20 * h + 20 * k + 20 * l }
    Material { .elemental(.carbon) }
  }
  let housing = LogicHousing(lattice: lattice)
  
  return [housing.rigidBody]
}

// Drafting the logic rods here.
#if false
func createGeometry() -> [Entity] {
  let lattice = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
  }
  let rod = Rod(lattice: lattice)
  
  return [rod.rigidBody]
}
#endif
