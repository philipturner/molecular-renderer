//
//  MRRenderer+Update.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation
import simd

@_alignment(16)
struct Arguments {
  var fovMultiplier: Float
  var positionX: Float
  var positionY: Float
  var positionZ: Float
  var rotation: simd_float3x3
  var jitter: SIMD2<Float>
  var frameSeed: UInt32
  var numLights: UInt16
  
  var minSamples: Float16
  var maxSamples: Float16
  var qualityCoefficient: Float16
  
  var maxRayHitTime: Float
  var exponentialFalloffDecayConstant: Float
  var minimumAmbientIllumination: Float
  var diffuseReflectanceScale: Float
  
  var denseDims: SIMD3<UInt16>
}

extension MRRenderer {
  // Perform any updating work that happens before encoding the rendering work.
  // This should be called as early as possible each frame, to hide any latency
  // between now and when it can encode the rendering work.
  func updateResources() {
    self.updateGeometry(time)
    self.accelBuilder.updateResources()
    
    self.jitterFrameID += 1
    if offline {
      self.jitterOffsets = SIMD2(repeating: 0)
    } else {
      self.jitterOffsets = makeJitterOffsets()
    }
    self.textureIndex = (self.textureIndex + 1) % 2
    self.renderIndex = (self.renderIndex + 1) % 3
  }
  
  func updateGeometry(_ time: MRTimeContext) {
    if accelBuilder.sceneSize == .extreme, accelBuilder.builtGrid {
      return
    }
    
    var atoms = atomProvider.atoms(time: time)
    let styles = atomStyleProvider.styles
    let available = atomStyleProvider.available
    
    for i in atoms.indices {
      let element = Int(atoms[i].element)
      if available[element] {
        let radius = styles[element].radius
        atoms[i].radiusSquared = radius * radius
        atoms[i].flags = 0
      } else {
        let radius = styles[0].radius
        atoms[i].element = 0
        atoms[i].radiusSquared = radius * radius
        atoms[i].flags = 0x1 | 0x2
      }
    }
    
    if time.absolute.frames > 0 {
      guard accelBuilder.atoms.count == atoms.count else {
        fatalError(
          "Used motion vectors when last frame had different atom count.")
      }
      
      accelBuilder.motionVectors = (0..<atoms.count).map { i -> SIMD3<Float> in
        atoms[i].origin - accelBuilder.atoms[i].origin
      }
    } else {
      accelBuilder.motionVectors = Array(repeating: .zero, count: atoms.count)
    }
    
    self.accelBuilder.atoms = atoms
    self.accelBuilder.styles = styles
  }
  
  // TODO: - Add camera update function.
}
