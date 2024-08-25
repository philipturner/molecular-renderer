//
//  MRRenderer+Update.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation
import simd

extension MRRenderer {
  func updateGeometry() {
    guard let time = argumentContainer.time else {
      fatalError("Time was not specified.")
    }
    argumentContainer.currentAtoms = atomProvider.atoms(time: time)
    
    // Shrinking the limit on atom count to 4 million, for the time being.
    guard argumentContainer.currentAtoms.count < 4 * 1024 * 1024 else {
      fatalError("Atom count was too large.")
    }
    
    // Specify whether to use motion vectors.
    if time.absolute.frames > 0,
       time.relative.frames > 0,
       argumentContainer.currentAtoms.count == argumentContainer.previousAtoms.count {
      argumentContainer.useMotionVectors = true
    } else {
      argumentContainer.useMotionVectors = false
    }
    
    // Allocate extra memory for motion vectors.
    switch argumentContainer.useMotionVectors {
    case true:
      var newVectors: [SIMD3<Float>] = []
      for i in argumentContainer.currentAtoms.indices {
        let current = argumentContainer.currentAtoms[i]
        let previous = argumentContainer.previousAtoms[i]
        let delta = current - previous
        newVectors.append(unsafeBitCast(delta, to: SIMD3<Float>.self))
      }
      bvhBuilder.motionVectors = newVectors
    case false:
      var newVectors: [SIMD3<Float>] = []
      for i in argumentContainer.currentAtoms.indices {
        newVectors.append(.zero)
      }
      bvhBuilder.motionVectors = newVectors
    default:
      fatalError("Did not specify whether to use motion vectors.")
    }
  }
}
