//
//  Flywheel.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/26/23.
//

import Foundation
import HDL
import QuaternionModule

public struct Flywheel {
  public var centers: [SIMD3<Float>]
  
  // TODO: Measure how fast this thing can spin without crashing the simulator.
  // When making this parametric, define the perimeter to it's always slightly
  // larger than what the radius would permit, to prevent the carbon bonds from
  // being pre-stretched?
  public init() {
    let radiusSize = 20
    let perimeterSize1 = 24 // 44
    let radius = try! DiamondRope(
      height: 1.5, width: 1, length: radiusSize).lattice
    let perimeter = try! DiamondRope(
      height: 1.5, width: 1, length: perimeterSize1).lattice
    
    let segment = Solid { h, k, l in
      Copy { radius }
      Affine {
        Copy { perimeter }
        Translate { -Float(perimeterSize1) / 2 * (h + l) }
        Rotate { 0.25 * k }
        Translate { Float(radiusSize) * (h + l) }
        Translate { 1.00 * (h + l) + 0.25 * (h - l) - 0.25 * k }
      }
    }
    
    let perimeterSize = Float(perimeterSize1) + 0.25
    let solid = Solid { h, k, l in
      for i in 0..<4 {
        Affine {
          Copy { segment }
          Translate { Float(i) * perimeterSize * (h - l) }
          if i % 2 == 1 {
            Reflect { k }
            Translate { 0.75 * k + 0 * (h - l) }
          }
        }
      }
    }
    
    func deduplicate(_ atoms: [SIMD3<Float>]) -> [SIMD3<Float>] {
      var newAtoms: [SIMD3<Float>] = []
      for i in 0..<atoms.count {
        let atom = atoms[i]
        if newAtoms.contains(where: {
          let delta = $0 - atom
          return sqrt((delta * delta).sum()) < 0.001
        }) {
          continue
        } else {
          newAtoms.append(atom)
        }
      }
      return newAtoms
    }
    
    centers = deduplicate(solid._centers)
    
    let centerOfWorld: SIMD3<Float> = 1 * [1, 0, 1]
    centers = centers.map { xyz in
      let center = xyz - centerOfWorld
      let distancePerim = (center * [1, 0, -1]).sum() / 2
      let distanceRad = (center * [1, 0, 1]).sum() / 2
      let perimeterProportion = distancePerim / (4 * Float(perimeterSize))
      
      if distanceRad < Float(radiusSize) - 0.25 {
        // rotate around axis, to the nearest multiple of 25 degrees
        let perimeterAdjusted = rint(4 * perimeterProportion) / 4
        let rotation = Quaternion(
          angle: perimeterAdjusted * 2 * Float.pi, axis: [0, 1, 0])
        
        var output = center
        output -= perimeterAdjusted * 4 * [1, 0, -1] * Float(perimeterSize)
        output = rotation.act(on: output)
        
        let targetY: Float = (
          Int(perimeterAdjusted * 4) % 2 == 0) ? -0.125 : 0.125
        if distanceRad < 2 {
          output.y += targetY
        } else if distanceRad < Float(radiusSize) {
          var proportion = (distanceRad - 2) / Float(radiusSize - 2)
          proportion = 1 - proportion
          output.y += targetY * proportion
        }
        return output
      } else {
        // rotate around axis perfectly
        return center
      }
    }
    
    centers = deduplicate(centers)
  }
}
