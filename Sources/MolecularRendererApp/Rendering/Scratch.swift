// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MolecularRenderer
import Numerics

// TODO: Move this scratch into the hardware catalog instead of a
// GitHub gist. Name the folder "ConvergentAssemblyArchitecture".
// - Add thumbnail to folder once the film is released.
// - Also add poster cataloguing the crystolecules.

func createNanomachinery() -> [MRAtom] {
  let scene = FactoryScene()
  Media.reportBillOfMaterials(scene)
  
//  print("Returning early.")
  exit(0)
//  return scene.createAtoms()
}
