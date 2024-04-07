import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Test that the drive system actually works with MD before doing anything
// else. It doesn't have to be serialized to the disk yet. You might gain some
// insights from serializing the minimized structures for other things in the
// scene.

// TODO: Fire up the old AFM probe embedded into the hardware catalog and/or
// the HDL unit tests. Design a good tooltip and set up a scripting environment
// for tripod build sequences.
// - Silicon probe, but (H3C)3-Ge* tooltip.
// - Create a build sequence compiler using the known set of reactions, after
//   this environment is set up. Pretend the germanium atoms are actually C.
// - 8885 atoms, estimated 50,000 tripods

func createGeometry() -> Animation {
  let animation = Animation()
  return animation
}
