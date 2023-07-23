//
//  Chapter9_Figure5.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import MolecularRenderer
import simd

extension Nanosystems.Chapter9 {
  struct Figure5: Figure3D {
    var a: Diamondoid
    var b: Diamondoid
    var c: Diamondoid
    
    init() {
      let ccBondLength: Float = 0.154
      var baseLayer: [SIMD3<Float>] = [.zero]
      for i in 1..<12 {
        var delta: SIMD3<Float>
        switch i % 4 {
        case 0, 2:
          delta = [+ccBondLength, 0, 0]
        case 1:
          delta = sp2Delta(
            start: [+ccBondLength, 0, 0], axis: [0, -1, 0])
        case 3:
          delta = sp2Delta(
            start: [+ccBondLength, 0, 0], axis: [0, +1, 0])
        default:
          fatalError("This should never happen.")
        }
        baseLayer.append(baseLayer.last! + delta)
      }
      
      func makeRod(n_bond: Int) -> Diamondoid {
        var centers: [SIMD3<Float>] = []
        var delta: SIMD3<Float> = .zero
        delta += sp2Delta(
          start: [+ccBondLength, 0, 0], axis: [0, -1, 0])
        delta += sp2Delta(
          start: [-ccBondLength, 0, 0], axis: [0, +1, 0])
        
        var currentLayer: [SIMD3<Float>] = baseLayer
        centers.append(contentsOf: baseLayer)
        for _ in 1..<n_bond {
          currentLayer = currentLayer.map { $0 + delta }
          centers.append(contentsOf: currentLayer)
        }
        let originalCircumference = Float(n_bond) * length(delta)
        var currentRadius = originalCircumference / (2 * .pi)
        
        func makeOutput() -> [SIMD3<Float>] {
          centers.map {
            let center = $0
            precondition(abs(center.y) < 0.001, "Cannot have a Y dimension.")
            let angle = (2 * .pi) * (center.z / originalCircumference)
            let rotation = simd_quatf(angle: angle, axis: [+1, 0, 0])
            
            let start: SIMD3<Float> = SIMD3(center.x, currentRadius, 0)
            return simd_act(rotation, start)
          }
        }
        
        func getScaleFactor(_ centers: [SIMD3<Float>]) -> Float {
          let originalDelta = centers[1] - centers[0]
          let adjacent = originalDelta.x
          
          let originalOpposite = length(
            originalDelta - adjacent * SIMD3(1, 0, 0))
          var originalLenSq = originalOpposite * originalOpposite
          originalLenSq += adjacent * adjacent
          let lengthDifference = length(originalDelta) - sqrt(originalLenSq)
          precondition(
            abs(lengthDifference) < 0.001,
            "Unable to compute distances correctly with trigonometry.")
          
          var newOpposite = ccBondLength * ccBondLength - adjacent * adjacent
          newOpposite = sqrt(newOpposite)
          return newOpposite / originalOpposite
        }
        let scaleFactor = getScaleFactor(makeOutput())
        print("Scaling radius by: \(scaleFactor)")
        
        currentRadius *= scaleFactor
        let output = makeOutput()
        let newScaleFactor = getScaleFactor(output)
        guard abs(newScaleFactor - 1) < 0.001 else {
          fatalError(
            "Got final scale factor '\(newScaleFactor)', but expected 1.")
        }
        return Diamondoid(carbonCenters: output)
      }
      
      self.a = makeRod(n_bond: 2)
      self.b = makeRod(n_bond: 3)
      self.c = makeRod(n_bond: 4)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a, \.b, \.c]
    }
    
    var stackingDirection: SIMD3<Float> {
      SIMD3(0, -1, 0)
    }
  }
}
