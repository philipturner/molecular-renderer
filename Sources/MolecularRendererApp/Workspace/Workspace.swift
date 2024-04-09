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
  //
  // For the moment, run through the entire sequence, up to carbene, using just
  // the adamantane cage and GFN2-xTB. If that fails, the effort spent on
  // GFN-FF might be wasted.
  
  // first array slot - line 1902
  // first suspected leg atom - line 1924
  // last suspected leg atom - line 1971
  var tinTripodAtoms = TripodCache.tinSet.hydrogen
  tinTripodAtoms.removeSubrange(1924 - 1902...1971 - 1902)
  // TODO: Form a Topology and add missing hydrogens, as anchors.
  
  var germaniumTripodAtoms = TripodCache.germaniumSet.radical
  
  germaniumTripodAtoms = germaniumTripodAtoms.map {
    var copy = $0
    copy.position.y = -copy.position.y
    copy.position.y += 2.00
    return copy
  }
  return tinTripodAtoms + germaniumTripodAtoms
}
