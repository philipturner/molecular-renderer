//
//  Scratch4.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/17/23.
//

import Foundation
import HDL
import MolecularRenderer
import Numerics

// MARK: - Very Complex Code for Solving Implicit Boundary Conditions

extension Quadrant {
  static func beltHeightMap(_ x: Float) -> Float? {
    if x > 15 {
      return nil
    }
    
    let arguments: [(SIMD3<Float>, SIMD2<Float>)] = [
      (SIMD3(-59.8, 5, 0.5), SIMD2(-100, 100)),
      (SIMD3(-27.3, 5, 0.5), SIMD2(-100, -27.3)),
      (SIMD3(-25.3, 5.6, 0.1), SIMD2(-27.3, -23.3)),
      (SIMD3(-23.3, 5, 0.5), SIMD2(-23.3, -21.3)),
      (SIMD3(-21.3, 3, 1), SIMD2(-21.3, 100)),
    ]
    
    var output: Float = 1.5
    for (argument, range) in arguments {
      if x < range[0] || x > range[1] {
        continue
      }
      let distance = abs(x - argument[0])
      let elevation = argument[1] - distance * argument[2]
      output = max(output, elevation)
    }
    return output - 23.5
  }
  
  static func createBeltLinks() -> [Diamondoid] {
    let lattice = createBeltLink()
    var masterBeltLink = Diamondoid(lattice: lattice)
    masterBeltLink.atoms.append(
      MRAtom(origin: [5.5, 0.5, 6], element: 7))
    masterBeltLink.atoms.append(
      MRAtom(origin: [Float(5.5) - 3.8, 0.5, 5.8], element: 16))
    
    // originally x=-45, y=2-23.5, z=-20.8
    masterBeltLink.translate(offset: [-65, Float(5) - 23.5, -20.8])
    var output = [masterBeltLink]
    var masterCopy = masterBeltLink
    masterCopy.atoms.removeAll(where: {
      $0.element != 1 && $0.element != 6
    })
    let masterBoundingBox = masterCopy.createBoundingBox()
    
    // Before: 823 ms
    // After: ??? ms
    let numLinks = 20
    var angles = [Float](repeating: 0, count: numLinks)
    for i in 1..<numLinks {
      let firstSulfur = masterBeltLink.atoms.last(where: { $0.element == 16 })!
      let lastNitrogen = output.last!.atoms.last(where: { $0.element == 7 })!
      var translation = lastNitrogen.origin - firstSulfur.origin
      translation.z = 0
      
      var copy = masterBeltLink
      copy.translate(offset: translation)
      
      var boundingBox = masterBoundingBox
      boundingBox.0 += translation
      boundingBox.1 += translation
      boundingBox.0.z = -18
      boundingBox.1.z = -18
      
      // Fail early if the bounding box is beyond the finish line.
      do {
        var centerX: Float = .zero
        centerX += boundingBox.0.x
        centerX += boundingBox.1.x
        centerX /= 2
        if Self.beltHeightMap(centerX) == nil {
          angles[i] = -100
          break
        }
      }
      
      var testPoints: [SIMD3<Float>] = []
      for i in 0...50 {
        let progress = Float(i) / 50
        var output = boundingBox.0
        output.x += (boundingBox.1.x - boundingBox.0.x) * progress
        testPoints.append(output)
      }
      for xValue in [boundingBox.0.x, boundingBox.1.x] {
        for i in 1...20 {
          let progress = Float(i) / 20
          var output = boundingBox.0
          output.x = xValue
          output.y += (boundingBox.1.y - boundingBox.0.y) * progress
          testPoints.append(output)
        }
      }
      for point in testPoints {
        let atom = MRAtom(origin: point, element: 14)
        copy.atoms.append(atom)
      }
      
      typealias Matrix = (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)
      func makeMatrix(angle: Float) -> Matrix {
        let radians = angle * .pi / 180
        if abs(radians) < 1e-3 {
          return([1, 0, 0], [0, 1, 0], [0, 0, 1])
        } else {
          let quaternion = Quaternion<Float>(angle: radians, axis: [0, 0, 1])
          return (
            quaternion.act(on: [1, 0, 0]),
            quaternion.act(on: [0, 1, 0]),
            quaternion.act(on: [0, 0, 1]))
        }
      }
      @inline(__always)
      func rotate(_ point: SIMD3<Float>, _ matrix: Matrix) -> SIMD3<Float> {
        matrix.0 * point.x +
        matrix.1 * point.y +
        matrix.2 * point.z
      }
      
      // Use this pivot to flip the sign of the favored rotation direction.
      let nitrogenX = lastNitrogen.origin.x
      var lastSecureAngle = angles[i]
      var secureAngleExists = false
      for _ in 0..<50 {
        let rotationMatrix = makeMatrix(angle: angles[i])
        var anyRepelled: Bool = false
        var anyAttracted: Bool = false
        var leverageRepel: Float = 0
        var leverageAttract: Float = 0
        for point in testPoints {
          let leverage = point.x - nitrogenX
          
          var delta = point - lastNitrogen.origin
          delta = rotate(delta, rotationMatrix)
          let transformed = lastNitrogen.origin + delta
          let currentHeight = transformed.y
          let surfaceHeight =
          Self.beltHeightMap(transformed.x) ?? Self.beltHeightMap(14)!
          if surfaceHeight > currentHeight {
            anyRepelled = true
            leverageRepel += (surfaceHeight - currentHeight) * leverage
          } else {
            anyAttracted = true
            leverageAttract += (currentHeight - surfaceHeight) * leverage
          }
        }
        
        guard anyRepelled || anyAttracted else {
          fatalError("No points repelled or attracted.")
        }
        var angleChange: Float
        if anyRepelled {
          angleChange = (leverageRepel > 0) ? 1 : -1
        } else {
          lastSecureAngle = angles[i]
          secureAngleExists = true
          angleChange = (leverageAttract < 0) ? 1 : -1
        }
        
        var newAngle = angles[i] + angleChange
        newAngle = max(-80, min(newAngle, 80))
        angles[i] = newAngle
      }
      if secureAngleExists {
        angles[i] = lastSecureAngle
      }
      let rotationMatrix = makeMatrix(angle: angles[i])
      
      // Move slightly outward from the window.
      var translationZ: Float = -0.1 * Float(i)
      if lastNitrogen.origin.z + translationZ < -18 {
        translationZ = -18 - lastNitrogen.origin.z
      } else {
      }
      copy.transform {
        var delta = $0.origin - lastNitrogen.origin
        delta = rotate(delta, rotationMatrix)
        $0.origin = lastNitrogen.origin + delta
        $0.origin.z += translationZ
      }
      output.append(copy)
    }
    
    for i in output.indices {
      output[i].atoms.removeAll(where: {
        $0.element != 1 && $0.element != 6 && $0.element != 79
      })
    }
    return output
  }
}
