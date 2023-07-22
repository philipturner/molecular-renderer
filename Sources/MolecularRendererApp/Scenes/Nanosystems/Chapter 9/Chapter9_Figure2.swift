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
    var c: Diamondoid
    
    init() {
      let ccBondLength: Float = 0.154
      
      var carbonCenters: [SIMD3<Float>] = []
      func addLevel(
        transform: (SIMD3<Float>) -> SIMD3<Float>
      ) {
        var output: [SIMD3<Float>] = [.zero]
        for i in 0..<6 {
          var delta: SIMD3<Float>
          if i % 2 == 0 {
            delta = sp3Delta(start: [0, -ccBondLength, 0], axis: [0, 0, +1])
          } else {
            delta = sp3Delta(start: [0, +ccBondLength, 0], axis: [0, 0, -1])
          }
          
          let center = output.last! + delta
          output.append(center)
        }
        for i in output.indices {
          output[i] = transform(output[i])
        }
        carbonCenters.append(contentsOf: output)
      }
      addLevel {
        return $0
      }
      self.a = Diamondoid(carbonCenters: carbonCenters)
      
      var secondLevelOrigin = carbonCenters[1]
      secondLevelOrigin += sp3Delta(
        start: [0, -ccBondLength, 0], axis: [-1, 0, 0])
      secondLevelOrigin += sp3Delta(
        start: [0, -ccBondLength, 0], axis: [0, 0, -1])
      
      addLevel {
        var center = $0
        center.y = -center.y
        center += secondLevelOrigin
        return center
      }
      self.b = Diamondoid(carbonCenters: carbonCenters)
      carbonCenters.removeLast(7)
      
      func rotateThirdLevel(
        _ center: SIMD3<Float>, degrees: Float
      ) -> SIMD3<Float> {
        let firstCenter = carbonCenters.first!
        var delta = center - firstCenter
        let translation = SIMD3(delta.x, 0, 0)
        delta.x = 0
        
        let rotation = simd_quatf(angle: degrees * .pi / 180, axis: [1, 0, 0])
        delta = simd_act(rotation, delta)
        return firstCenter + delta + translation
      }
      
      addLevel {
        var center = $0
        center.y = -center.y
        center += secondLevelOrigin
        return rotateThirdLevel(center, degrees: +10)
      }
      addLevel {
        var center = $0
        center.y = -center.y
        center += secondLevelOrigin
        center.z = -center.z
        return rotateThirdLevel(center, degrees: -10)
      }
      self.c = Diamondoid(carbonCenters: carbonCenters)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a, \.b, \.c]
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
