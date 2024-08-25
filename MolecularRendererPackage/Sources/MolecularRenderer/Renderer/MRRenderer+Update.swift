//
//  MRRenderer+Update.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation
import simd

extension MRRenderer {
  func updateResources() {
    self.updateGeometry(time: time)
    self.bvhBuilder.updateResources()
    
    argumentContainer.jitterFrameID += 1
    self.textureIndex = (self.textureIndex + 1) % 2
    self.renderIndex = (self.renderIndex + 1) % 3
  }
  
  func updateGeometry(time: MRTime) {
    var atoms = atomProvider.atoms(time: time)
    
    // TODO: Fuse this with the GPU kernel that reduces the bounding box.
    if time.absolute.frames > 0,
       time.relative.frames > 0,
       bvhBuilder.atoms.count == atoms.count {
      var newVectors = [SIMD3<Float>](repeating: .zero, count: atoms.count)
      for i in atoms.indices {
        let current = atoms[i]
        let previous = bvhBuilder.atoms[i]
        let delta = current - previous
        newVectors[i] = unsafeBitCast(delta, to: SIMD3<Float>.self)
      }
      bvhBuilder.motionVectors = newVectors
    } else {
      bvhBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    }
    
    self.bvhBuilder.atoms = atoms
    self.bvhBuilder.atomRadii = atomRadii
  }
}
