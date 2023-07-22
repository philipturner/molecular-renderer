//
//  Chapter9_Figure2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import Foundation
import MolecularRenderer
import simd

extension Nanosystems.Chapter9 {
  struct Figure2: Figure3D {
    var a: Diamondoid
    var b: Diamondoid
    
    init() {
      let ccBondLength: Float = 0.154
      
      func sp3Delta(
        start: SIMD3<Float>, axis: SIMD3<Float>
      ) -> SIMD3<Float> {
        let sp3BondAngle: Float = 109.5 * .pi / 180
        let rotation = simd_quatf(angle: sp3BondAngle / 2, axis: axis)
        return simd_act(rotation, start)
      }
      
      
      var carbonCenters: [SIMD3<Float>] = [.zero]
      for i in 0..<6 {
        var delta: SIMD3<Float>
        if i % 2 == 0 {
          delta = sp3Delta(start: [0, -ccBondLength, 0], axis: [0, 0, +1])
        } else {
          delta = sp3Delta(start: [0, +ccBondLength, 0], axis: [0, 0, -1])
        }
        
        let center = carbonCenters.last! + delta
        carbonCenters.append(center)
      }
      
      self.a = Diamondoid(carbonCenters: carbonCenters)
      self.b = Diamondoid(carbonCenters: carbonCenters)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a, \.b]
    }
    
    var stackingDirection: SIMD3<Float> {
      SIMD3(0, 1, 0)
    }
  }
  
  struct Figure5/*: Figure3D*/ {
    
  }
  
  struct Figure6/*: Figure3D*/ {
    
  }
}
