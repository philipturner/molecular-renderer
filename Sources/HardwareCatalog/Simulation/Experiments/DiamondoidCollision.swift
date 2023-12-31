//
//  DiamondoidCollision.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/30/23.
//

import Foundation
import HDL
import MolecularRenderer
import QuaternionModule

struct DiamondoidCollision {
  var provider: OpenMM_AtomProvider
  
  init() {
    let horizontalSpacing: Float = /*0.3*/ 0.5 * 6 // nm
    let approachSpeed: Float = /*0.2*/ 0.5 * 4 // nm/ps, v2 - v1
    
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
    
    var carbonCenters: [SIMD3<Float>] = []
    
    do {
      let layerWidth: Int = 100
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
        
        let rotation = Quaternion<Float>(angle: degrees * .pi / 180, axis: [1, 0, 0])
        delta = rotation.act(on: delta)
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
    }
    
    var baseDiamondoid = Diamondoid(carbonCenters: carbonCenters)
    baseDiamondoid.translate(offset: -baseDiamondoid.createCenterOfMass())
    
    var diamondoids: [Diamondoid] = []
    for i in -1...1 where i != 0 {
      var translation: SIMD3<Float>
      var rotation: Quaternion<Float>
      var velocity: SIMD3<Float>
      
      switch i {
      case -1:
        translation = [-horizontalSpacing / 2, 0, 0]
        rotation = Quaternion<Float>(angle: .pi / 2, axis: [0, 0, +1])
        velocity = [approachSpeed / 2, 0, 0]
      case 1:
        translation = [+horizontalSpacing / 2, 0, 0]
        rotation = Quaternion<Float>(angle: .pi / 2, axis: [0, -1, 0])
        velocity = [-approachSpeed / 2, 0, 0]
      default:
        fatalError("This should never happen.")
      }
      
      var diamondoid = baseDiamondoid
      diamondoid.rotate(angle: rotation)
      diamondoid.translate(offset: translation)
      diamondoid.linearVelocity = velocity
      diamondoids.append(diamondoid)
    }
    
    var numAtoms = 0
    for diamondoid in diamondoids {
      numAtoms += diamondoid.atoms.count
    }
    print("Atom count: \(numAtoms)")
    
    let simulator = MM4(diamondoids: diamondoids, fsPerFrame: 20)
    simulator.simulate(ps: 20) // 10, or 200 to measure energy drift
    provider = simulator.provider
  }
}

// Like DiamondoidCollision, but using OpenMM external forces and anchors to
// drive the motion.
struct LonsdaleiteCollision {
  var provider: any MRAtomProvider
  
  init() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 10 * (h + h2k + l) }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 5 * (h + h2k + l) }
        Convex {
          for direction in [h, h + k, k, -h, -h - k, -k] {
            Convex {
              Origin { 3 * direction }
              Plane { direction }
            }
          }
        }
        Replace { .empty }
      }
    }
    
    let atoms = lattice.atoms.map(MRAtom.init)
    self.provider = ArrayAtomProvider(atoms)
    
    var diamondoid1 = Diamondoid(atoms: atoms)
    print("Atom count: \(diamondoid1.atoms.count * 2)")
    diamondoid1.minimize()
    diamondoid1.translate(offset: -diamondoid1.createCenterOfMass())
    
    var diamondoid2 = diamondoid1
    diamondoid2.translate(offset: [0, 3.5, 0])
    diamondoid2.externalForce = [0, -1000, 0]
    diamondoid2.atomsWithForce = diamondoid2.atoms.map {
      $0.z < 0
    }
    
    // Change a few random atoms in diamondoid1 to anchors.
    diamondoid1.anchors = [Bool](
      repeating: false, count: diamondoid1.atoms.count)
    let numAnchors = Int(Float(diamondoid1.atoms.count) / 20)
    for _ in 0..<numAnchors {
      let randomAtom = diamondoid1.atoms.indices.randomElement()!
      diamondoid1.anchors[randomAtom] = true
    }
    self.provider = ArrayAtomProvider(diamondoid1.atoms + diamondoid2.atoms)
    
    let simulator = MM4(
      diamondoids: [diamondoid1, diamondoid2], fsPerFrame: 100)
    simulator.simulate(ps: 20)
    self.provider = simulator.provider
  }
}
