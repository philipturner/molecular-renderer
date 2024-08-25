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
    var atoms = atomProvider.atoms(time: time)
    
    // Shrinking the limit on atom count to 4 million, for the time being.
    guard atoms.count < 4 * 1024 * 1024 else {
      fatalError("Atom count was too large.")
    }
    
    // Specify whether to use motion vectors.
    if time.absolute.frames > 0,
       time.relative.frames > 0,
       bvhBuilder.atoms.count == atoms.count {
      argumentContainer.useMotionVectors = true
    } else {
      argumentContainer.useMotionVectors = false
    }
    
    // Allocate extra memory for motion vectors.
    switch argumentContainer.useMotionVectors {
    case true:
      var newVectors = [SIMD3<Float>](repeating: .zero, count: atoms.count)
      for i in atoms.indices {
        let current = atoms[i]
        let previous = bvhBuilder.atoms[i]
        let delta = current - previous
        newVectors[i] = unsafeBitCast(delta, to: SIMD3<Float>.self)
      }
      bvhBuilder.motionVectors = newVectors
    case false:
      bvhBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    default:
      fatalError("Did not specify whether to use motion vectors.")
    }
    
    // Assign the atoms to the BVH builder.
    self.bvhBuilder.atoms = atoms
    self.bvhBuilder.atomRadii = atomRadii
  }
}
