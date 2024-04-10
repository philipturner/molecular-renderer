import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Goal: Animate a build sequence for a small logic rod.

func createGeometry() -> [Entity] {
  var probe = Probe()
  probe.project(distance: 3)
  
  let surfaceTripod = Tripod(atoms: TripodCache.tinSet.methylene)
  return probe.createFrame() + surfaceTripod.createFrame()
}
