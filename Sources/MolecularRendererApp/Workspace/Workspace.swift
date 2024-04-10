import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Goal: Animate a build sequence for a small logic rod.

func createGeometry() -> [Entity] {
  let surface = Surface()
  let tripod = Tripod(atoms: TripodCache.tinCappedSet.methylene)
  return surface.topology.atoms + tripod.createFrame()
}
