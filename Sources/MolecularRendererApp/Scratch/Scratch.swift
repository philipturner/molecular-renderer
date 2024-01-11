// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics
import OpenMM

func createGeometry() -> [Entity] {
  // Use the acetylene tutorial from the xTB docs until we get XTBProcess
  // working, with a lower-latency workflow that can execute in a single
  // Swift program.
  var acetyleneAtoms: [Entity] = []
  acetyleneAtoms.append(Entity(position: [0, 0, 0], type: .atom(.hydrogen)))
  acetyleneAtoms.append(Entity(position: [0.11, 0, 0], type: .atom(.carbon)))
  acetyleneAtoms.append(Entity(position: [0.23, 0, 0], type: .atom(.carbon)))
  acetyleneAtoms.append(Entity(position: [0.34, 0, 0], type: .atom(.hydrogen)))
  
  let process = XTBProcess(path: "/Users/philipturner/Documents/OpenMM/xtb/cpu0")
  process.writeSettings()
  return acetyleneAtoms
}
