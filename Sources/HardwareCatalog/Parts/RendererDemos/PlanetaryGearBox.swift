//
//  PlanetaryGearBox.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/12/23.
//

import Foundation
import MolecularRenderer

// Test case used for evaluating performance of the ray tracer.
// - Benchmarked quality: 3 samples/pixel
// - Benchmarked position: ~0.5-1.0 nm above origin, looking at +Z
// - 16-bit references
struct PlanetaryGearBox: MRAtomProvider {
  var _atoms: [MRAtom]
  
  init() {
    let parser = NanoEngineerParser(
      partLibPath: "gears/MarkIII[k] Planetary Gear Box")
    self._atoms = parser._atoms
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    return self._atoms
  }
}
