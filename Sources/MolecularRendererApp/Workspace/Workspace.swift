import Foundation
import HDL
import MM4
import Numerics

// Notes for this branch:
// - Recycle the AFM probe from the incomplete bootstrapping animation (good
//   match for theoretical model of a 40 Å sphere).
// - nc-AFM image resolved by repeatedly forming and breaking Si-Si covalent
//   bonds, between the surface and tip.
// - Silicon wafers are typically heated to 1050°C, removing H termination.
// - AFM probe oscillated with an amplitude of 257 Å in the paper.
// - Figure 1(c) of https://doi.org/10.1103/PhysRevB.58.10835 uses
//   four-membered rings.
//
// End goal:
// - Decently well-crafted animation of the Si(111)-7x7 experiment.
func createGeometry() -> [Entity] {
  // First task:
  // - Compile a scene with a decently large silicon surface, and the AFM probe
  //   modeled after Herman1999.
  // - Compile a large MM4 simulation of ambient motion at 273+1050 K, and a
  //   probabilistic function where the hydrogens leave the Si surfaces.
  // - Compile an animation of the (mostly depassivated) probe oscillating
  //   between two points located 25.7 nm apart.
  // - Using the _continuity of motion_ principle, fade away most atoms in the
  //   scene, except for a few that will be sent through xTB.
  // - Compile the apex of the tooltip (the atom that makes 4-membered rings).
  //   Alternatively, the tooltip without this atom seems more likely to
  //   retract a silicon atom from the surface.
  return []
}
