//
//  Chapter9_Figure6.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import MolecularRenderer
import simd

extension Nanosystems.Chapter9 {
  struct Figure6: Figure3D {
    var a: Diamondoid
    var b: Diamondoid
    var c: Diamondoid
    var d: Diamondoid
    
    init() {
      func makeRod(n_bonds: Int, crossRingBondAngle: Float) -> Diamondoid {
        var baseInnerRing: [SIMD3<Float>] = [.zero]
        var ringDelta: SIMD3<Float> = [0, 0, +ccBondLength]
        let polygonAngle = .pi * Float(n_bonds - 2) / Float(n_bonds)
        
        func makeCentered(_ positions: [SIMD3<Float>]) -> [SIMD3<Float>] {
          let averagePosition = positions.reduce(SIMD3<Float>.zero) {
            $0 + $1
          } / Float(positions.count)
          return positions.map { $0 - averagePosition }
        }
        
        while baseInnerRing.count < n_bonds {
          baseInnerRing.append(baseInnerRing.last! + ringDelta)
          
          let rotation = simd_quatf(angle: -polygonAngle, axis: [+1, 0, 0])
          ringDelta = simd_act(rotation, -ringDelta)
        }
        baseInnerRing = makeCentered(baseInnerRing)
        
        let baseOuterRing = baseInnerRing.indices.map { i -> SIMD3<Float> in
          let center = baseInnerRing[i]
          let neighborCenters = [-1, +1].map { indexDelta in
            var index = i + indexDelta
            index = (index + n_bonds) % n_bonds
            return baseInnerRing[index]
          }
          
          let axis = normalize(neighborCenters[1] - neighborCenters[0])
          let rotation = simd_quatf(
            angle: -(.pi - crossRingBondAngle), axis: axis)
          
          let midPoint = (neighborCenters[0] + neighborCenters[1]) / 2
          let normal = normalize(center - midPoint)
          let direction = simd_act(rotation, normal)
          return center + ccBondLength * direction
        }
        
        let sectorAngle: Float = 2 * .pi / Float(n_bonds)
        let sectorRotation = simd_quatf(
          angle: sectorAngle / 2, axis: [+1, 0, 0])
        var rotatedOuterRing = baseOuterRing.map { center in
          return simd_act(sectorRotation, center)
        }
        
        do {
          let adjacent = distance(rotatedOuterRing[0], baseOuterRing[0])
          var opposite = ccBondLength * ccBondLength - adjacent * adjacent
          opposite = sqrt(opposite)
          precondition(abs(opposite) > 0.001, "Opposite too small.")
          
          rotatedOuterRing = rotatedOuterRing.map {
            return $0 + SIMD3(opposite, 0, 0)
          }
        }
        
        var rotatedInnerRing: [SIMD3<Float>]
        do {
          var deltaX = baseOuterRing[0].x - baseInnerRing[0].x
          deltaX = rotatedOuterRing[0].x + deltaX
          rotatedInnerRing = baseInnerRing.map {
            let center = $0 + SIMD3(deltaX, 0, 0)
            return simd_act(sectorRotation, center)
          }
        }
        
        var layers: [[SIMD3<Float>]] = [
          baseInnerRing, baseOuterRing,
          rotatedOuterRing, rotatedInnerRing
        ]
        for _ in 0..<3 {
          let previousLayers = layers[(layers.count - 4)...(layers.count - 2)]
          let currentLayer = layers[layers.count - 1]
          let currentX = currentLayer[0].x
          
          let nextLayers = previousLayers.reversed().map { layer in
            return layer.map { center in
              var deltaX = center.x - currentX
              deltaX = -2 * deltaX
              return center + SIMD3(deltaX, 0, 0)
            }
          }
          layers.append(contentsOf: nextLayers)
        }
        
        let centers: [SIMD3<Float>] = layers.flatMap { $0 }
        return Diamondoid(carbonCenters: centers)
      }
      
      a = makeRod(n_bonds: 3, crossRingBondAngle: 114 * .pi / 180)
      b = makeRod(n_bonds: 4, crossRingBondAngle: 120 * .pi / 180)
      c = makeRod(n_bonds: 5, crossRingBondAngle: 124 * .pi / 180)
      d = makeRod(n_bonds: 6, crossRingBondAngle: 128 * .pi / 180)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a, \.b, \.c, \.d]
    }
    
    var stackingDirection: SIMD3<Float> {
      SIMD3(0, -1, 0)
    }
  }
}
