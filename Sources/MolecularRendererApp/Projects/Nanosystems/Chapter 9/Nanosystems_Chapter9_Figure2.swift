//
//  Chapter9_Figure2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule

extension Nanosystems.Chapter9 {
  struct Figure2: NanosystemsFigure {
    var a: Diamondoid
    var b: Diamondoid
    var c: Diamondoid
    var d: Diamondoid
    var e: Diamondoid
    var f: Diamondoid
    
    init() {
      let ccBondLength = Constants.bondLengths[[6, 6]]!.average
      
      var baseLayer: [SIMD3<Float>] = [.zero]
      for i in 0..<6 {
        var delta: SIMD3<Float>
        if i % 2 == 0 {
          delta = sp3Delta(start: [0, +ccBondLength, 0], axis: [0, 0, -1])
        } else {
          delta = sp3Delta(start: [0, -ccBondLength, 0], axis: [0, 0, +1])
        }
        
        let center = baseLayer.last! + delta
        baseLayer.append(center)
      }
      
      var carbonCenters: [SIMD3<Float>] = []
      carbonCenters += baseLayer.map {
        var center = $0
        center.y = -center.y
        return center
      }
      self.a = Diamondoid(carbonCenters: carbonCenters)
      
      var secondFigureOrigin = carbonCenters[1]
      secondFigureOrigin += sp3Delta(
        start: [0, -ccBondLength, 0], axis: [-1, 0, 0])
      secondFigureOrigin += sp3Delta(
        start: [0, -ccBondLength, 0], axis: [0, 0, -1])
      
      carbonCenters += baseLayer.map {
        return secondFigureOrigin + $0
      }
      self.b = Diamondoid(carbonCenters: carbonCenters)
      
      func rotateThirdFigureLayer(
        _ center: SIMD3<Float>, degrees: Float
      ) -> SIMD3<Float> {
        let firstCenter = carbonCenters.first!
        var delta = center - firstCenter
        let translation = SIMD3(delta.x, 0, 0)
        delta.x = 0
        
        let rotation = Quaternion<Float>(angle: degrees * .pi / 180, axis: [1, 0, 0])
        delta = rotation.act(on: delta)
        return firstCenter + delta + translation
      }
      
      carbonCenters.removeLast(7)
      carbonCenters += baseLayer.map {
        let center = secondFigureOrigin + $0
        return rotateThirdFigureLayer(center, degrees: +10)
      }
      carbonCenters += baseLayer.map {
        var center = secondFigureOrigin + $0
        center.z = -center.z
        return rotateThirdFigureLayer(center, degrees: -10)
      }
      self.c = Diamondoid(carbonCenters: carbonCenters)
      
      func layer(positiveSteps: Int, negativeSteps: Int) -> [SIMD3<Float>] {
        var output: [SIMD3<Float>] = baseLayer
        var flipped = false
        
        func moveZ(positive: Bool) {
          var delta: SIMD3<Float>
          if positive {
            delta = sp3Delta(start: [0, +ccBondLength, 0], axis: [+1, 0, 0])
          } else {
            delta = sp3Delta(start: [0, +ccBondLength, 0], axis: [-1, 0, 0])
          }
          output = output.map { $0 + delta }
          
          var rotationCenter: SIMD3<Float>
          if flipped {
            rotationCenter = output[0]
          } else {
            rotationCenter = output[1]
          }
          rotationCenter.x = 0
          
          let rotation = Quaternion<Float>(angle: .pi, axis: [+1, 0, 0])
          output = output.map {
            var delta = $0 - rotationCenter
            delta = rotation.act(on: delta)
            return rotationCenter + delta
          }
          flipped = !flipped
        }
        
        for _ in 0..<positiveSteps {
          moveZ(positive: true)
        }
        for _ in 0..<negativeSteps {
          moveZ(positive: false)
        }
        return output
      }
      
      carbonCenters.removeAll()
      carbonCenters += baseLayer
      carbonCenters += layer(positiveSteps: 1, negativeSteps: 0)
      carbonCenters += layer(positiveSteps: 0, negativeSteps: 1)
      carbonCenters += layer(positiveSteps: 1, negativeSteps: 1)
      self.d = Diamondoid(carbonCenters: carbonCenters)
      
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 0)
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 1)
      self.e = Diamondoid(carbonCenters: carbonCenters)
      
      carbonCenters += layer(positiveSteps: 0, negativeSteps: 2)
      carbonCenters += layer(positiveSteps: 1, negativeSteps: 2)
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 2)
      self.f = Diamondoid(carbonCenters: carbonCenters)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a, \.b, \.c, \.d, \.e, \.f]
    }
  }
}
