//
//  AtomProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import HDL
import MolecularRenderer

// TODO: Remove this entire file, once the atom specification API is reworked.

// MARK: - MRAtom Interface with Array

struct ArrayAtomProvider: MRAtomProvider {
  var atoms: [SIMD4<Float>]
  
  init(_ atoms: [SIMD4<Float>]) {
    self.atoms = atoms
  }
  
  func atoms(time: MRTime) -> [SIMD4<Float>] {
    return atoms
  }
}

struct AnimationAtomProvider: MRAtomProvider {
  var frames: [[SIMD4<Float>]]
  
  init(_ frames: [[SIMD4<Float>]]) {
    self.frames = frames
  }
  
  func atoms(time: MRTime) -> [SIMD4<Float>] {
    if frames.count == 0 {
      return []
    }
    
    var frameID = time.absolute.frames
    frameID = min(frameID, frames.count - 1)
    return frames[frameID]
  }
}
