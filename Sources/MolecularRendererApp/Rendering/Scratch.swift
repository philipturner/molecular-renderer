// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

// Add a variable within the function that controls whether it starts out as
// sp2 or sp3.
func createSilyleneTooltip(sp3: Bool) -> [MRAtom] {
  var tripodAtoms = Bootstrapping.Tripod(position: .zero).atoms
  let germanium = tripodAtoms.first(where: {
    $0.element == 32
  })!
  
  let siliconLocation = tripodAtoms.firstIndex(where: {
    $0.element == 1 && $0.origin.y > germanium.y
  })!
  
  // Use 2.37 angstroms for the Si-Ge bond length.
  // Use 1.483 angstroms for the H-Si bond length
  var siliconPosition = germanium.origin
  siliconPosition.y += 2.37 / 10
  tripodAtoms[siliconLocation].origin = siliconPosition
  tripodAtoms[siliconLocation].element = 14
  
  var zenith: Float
  var azimuth: Float
  if sp3 {
    zenith = 109.47
    azimuth = 120.00
  } else {
    zenith = 120.00
    azimuth = 180.00
  }
  zenith *= .pi / 180
  azimuth *= .pi / 180
  
  var hydrogen1Delta: SIMD3<Float> = [0, -1, 0]
  let zenithRotation = Quaternion<Float>(angle: zenith, axis: [0, 0, 1])
  let azimuthRotation = Quaternion<Float>(angle: azimuth, axis: [0, 1, 0])
  hydrogen1Delta = zenithRotation.act(on: hydrogen1Delta)
  
  var hydrogen2Delta = hydrogen1Delta
  hydrogen2Delta = azimuthRotation.act(on: hydrogen2Delta)
  
  let hydrogenBondLength: Float = 1.483 / 10
  for delta in [hydrogen1Delta, hydrogen2Delta] {
    let position = siliconPosition + delta * hydrogenBondLength
    let atom = MRAtom(origin: position, element: 1)
    tripodAtoms.append(atom)
  }
  return tripodAtoms
}

// Another function to load the minimized structure in xTB. Don't forget to
// unfreeze the germanium atom in xtb.inp!
