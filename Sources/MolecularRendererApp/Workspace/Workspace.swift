import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// TODO: Can the carbene group successfully transfer from the tinCarbene tripod
// to the germaniumRadical tripod? From the tin tripod to the AFM probe with a
// germanium tip? What about leaving it partially activated (with a different
// halogen that will be activated at a different wavelength)? Then, covering
// the tripods with a thin shield to protect them from the UV light.

func createGeometry() -> [Entity] {
  // Use the hydrogen transfer between Sn and Ge as a simpler test case, for
  // troubleshooting the other components of the simulation. Try:
  // - (a) getting GFN-FF ONIOM to work, despite bond topology changing
  // - (b) serializing the simulation and replaying
  
  return TripodCache.tinSet.hydrogen + TripodCache.germaniumSet.radical.map {
    var copy = $0
    copy.position.y = -copy.position.y
    copy.position.y += 2.00
    return copy
  }
}
