import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Compile a design for a half adder. Energy-minimize the housing with
// positional constraints on the bulk atoms. Place the adder in the scene.
// Test whether it works in a constrained MD simulation, but delete the code
// and don't worry about animating it right now.
//
// Extract each logic rod, remove the hydrogens on one side, and arrange the
// finished products on the silicon surface. Compile a complete build sequence
// for every rod.

func createGeometry() -> [MM4RigidBody] {
  // TODO: Create a function that can minimize a rigid body in isolation, then
  // retrieve the serialized one from disk.
  
  let halfAdder = HalfAdder()
  var rigidBodies = halfAdder.rigidBodies
  return rigidBodies
}
