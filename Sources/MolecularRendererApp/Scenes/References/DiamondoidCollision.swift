//
//  DiamondoidCollision.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/30/23.
//

import Foundation
import MolecularRenderer
import simd

struct DiamondoidCollision {
  var provider: OpenMM_AtomProvider
  
  init() {
    let horizontalSpacing: Float = 6 // nm
    let approachSpeed: Float = 4 // nm/ps, v2 - v1
    var blockVelocities: [SIMD3<Float>] = []
    
    func centerAtOrigin(_ atoms: [MRAtom]) -> [MRAtom] {
      var totalMass: Float = .zero
      var centerOfMass: SIMD3<Float> = .zero
      for i in atoms.indices {
        let mass = 2 * Float(atoms[i].element)
        totalMass += mass
        centerOfMass += mass * atoms[i].origin
      }
      centerOfMass /= totalMass
      
      return atoms.map {
        var copy = $0
        copy.origin -= centerOfMass
        return copy
      }
    }
    
    var baseAtoms: [MRAtom]
    
    do {
      let layerWidth: Int = 3
      let ccBondLength = Constants.bondLengths[[6, 6]]!.average
      
      var baseLayer: [SIMD3<Float>] = [.zero]
      for i in 0..<layerWidth {
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
      
      var secondFigureOrigin = carbonCenters[1]
      secondFigureOrigin += sp3Delta(
        start: [0, -ccBondLength, 0], axis: [-1, 0, 0])
      secondFigureOrigin += sp3Delta(
        start: [0, -ccBondLength, 0], axis: [0, 0, -1])
      
      carbonCenters += baseLayer.map {
        return secondFigureOrigin + $0
      }
      
      func rotateThirdFigureLayer(
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
      
      carbonCenters.removeLast(layerWidth + 1)
      carbonCenters += baseLayer.map {
        let center = secondFigureOrigin + $0
        return rotateThirdFigureLayer(center, degrees: +10)
      }
      carbonCenters += baseLayer.map {
        var center = secondFigureOrigin + $0
        center.z = -center.z
        return rotateThirdFigureLayer(center, degrees: -10)
      }
      
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
          
          let rotation = simd_quatf(angle: .pi, axis: [+1, 0, 0])
          output = output.map {
            var delta = $0 - rotationCenter
            delta = simd_act(rotation, delta)
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
      
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 0)
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 1)
      
      carbonCenters += layer(positiveSteps: 0, negativeSteps: 2)
      carbonCenters += layer(positiveSteps: 1, negativeSteps: 2)
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 2)
      
      carbonCenters += layer(positiveSteps: 3, negativeSteps: 0)
      carbonCenters += layer(positiveSteps: 3, negativeSteps: 1)
      carbonCenters += layer(positiveSteps: 3, negativeSteps: 2)
      
      carbonCenters += layer(positiveSteps: 0, negativeSteps: 3)
      carbonCenters += layer(positiveSteps: 1, negativeSteps: 3)
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 3)
      carbonCenters += layer(positiveSteps: 3, negativeSteps: 3)
      
      carbonCenters += layer(positiveSteps: 4, negativeSteps: 0)
      carbonCenters += layer(positiveSteps: 4, negativeSteps: 1)
      carbonCenters += layer(positiveSteps: 4, negativeSteps: 2)
      carbonCenters += layer(positiveSteps: 4, negativeSteps: 3)
      
      carbonCenters += layer(positiveSteps: 0, negativeSteps: 4)
      carbonCenters += layer(positiveSteps: 1, negativeSteps: 4)
      carbonCenters += layer(positiveSteps: 2, negativeSteps: 4)
      carbonCenters += layer(positiveSteps: 3, negativeSteps: 4)
      carbonCenters += layer(positiveSteps: 4, negativeSteps: 4)
      
      baseAtoms = carbonCenters.map {
        MRAtom(origin: $0, element: 6)
      }
    }
    
    baseAtoms.removeAll(where: { $0.element == 1 })
    baseAtoms = centerAtOrigin(baseAtoms)
    
    var atoms: [MRAtom] = []
    for i in -1...1 where i != 0 {
      var translation: SIMD3<Float>
      var rotation: simd_quatf
      var velocity: SIMD3<Float>
      
      switch i {
      case -1:
        translation = [-horizontalSpacing / 2, 0, 0]
        rotation = simd_quatf(angle: .pi / 2, axis: [0, 0, +1])
        velocity = [approachSpeed / 2, 0, 0]
      case 1:
        translation = [+horizontalSpacing / 2, 0, 0]
        rotation = simd_quatf(angle: .pi / 2, axis: [0, -1, 0])
        velocity = [-approachSpeed / 2, 0, 0]
      default:
        fatalError("This should never happen.")
      }
      blockVelocities.append(velocity)
      
      atoms += baseAtoms.map { baseAtom in
        var atom = baseAtom
        atom.origin = translation + simd_act(rotation, atom.origin)
        atom.element = 6
        return atom
      }
    }
    
    let velocities = atoms.indices.map { i in
      if i % (2 * baseAtoms.count) < baseAtoms.count {
        return blockVelocities[0]
      } else {
        return blockVelocities[1]
      }
    }
    precondition(!velocities.contains(where: { length($0) < 0.01 }))
    let diamondoid = Diamondoid(atoms: atoms, velocities: velocities)
    print("Atom count: \(diamondoid.atoms.count)")
    
    let simulator = MM4(diamondoid: diamondoid, fsPerFrame: 100)
    simulator.simulate(ps: 10) // 10
    provider = simulator.provider
  }
}
