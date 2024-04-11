import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Goal: Animate a build sequence for a small logic rod.

func createGeometry() -> [Entity] {
  var surface = Surface()
  let supply = Supply()
  surface.transmuteOverlappingPassivators(supply: supply)
  
  var probe = Probe()
  probe.project(distance: 3)
  
  // TODO: Compile a design for a half adder. Energy-minimize the housing with
  // positional constraints on the bulk atoms, and serialize the atoms as a
  // base64 string. Place the adder somewhere in the scene. Also, design the
  // drive wall that actuates the rods.
  //
  // Extract each logic rod, remove the hydrogens on one side, and place the
  // finished products on the silicon surface. If we can compile a build
  // sequence for one, compiling sequences for the rest should be trivial.
  
  return surface.topology.atoms + supply.createFrame() + probe.createFrame()
}
