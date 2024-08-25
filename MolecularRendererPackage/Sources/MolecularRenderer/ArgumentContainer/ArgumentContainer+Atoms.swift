//
//  ArgumentContainer+Atoms.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension ArgumentContainer {
  mutating func updateAtoms(provider: MRAtomProvider) {
    guard let time else {
      fatalError("Time was not specified.")
    }
    currentAtoms = provider.atoms(time: time)
    
    // Shrinking the limit on atom count to 4 million, for the time being.
    guard currentAtoms.count < 4 * 1024 * 1024 else {
      fatalError("Atom count was too large.")
    }
    
    // Specify whether to use motion vectors.
    if time.absolute.frames > 0,
       time.relative.frames > 0,
       currentAtoms.count == previousAtoms.count {
      useAtomMotionVectors = true
    } else {
      useAtomMotionVectors = false
    }
  }
}
