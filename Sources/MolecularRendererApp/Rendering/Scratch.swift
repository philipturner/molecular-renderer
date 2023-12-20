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
//  Media.reportBillOfMaterials(scene)
  
  // The final version of the output will sort crystolecules by their bounding
  // boxes and produce a better image. It will be a 2D arrangement, curved to
  // surround the user.
  // - Every crystolecule's maximum Z coordinate must be flush.
  // - Reorient the parts toward the best direction for presentation.
  // - Curve the flush Z sheet around the user.
  
  // Place the largest pieces manually, have a random number generator place
  // the rest.
  return scene.createAtoms()
//  exit(0)
}


