import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Can the carbene group successfully transfer from the tinCarbene tripod
// to the germaniumRadical tripod? From the tin tripod to the AFM probe with a
// germanium tip?

// TODO: Fire up the old AFM probe embedded into the hardware catalog and/or
// the HDL unit tests. Design a good tooltip and set up a scripting environment
// for tripod build sequences.
// - Silicon probe, but (H3C)3-Ge* tooltip.

func createGeometry() -> [Entity] {
  return TripodCache.tinSet.carbene + TripodCache.germaniumSet.radical.map {
    var copy = $0
    copy.position.x += 2
    return copy
  }
}
