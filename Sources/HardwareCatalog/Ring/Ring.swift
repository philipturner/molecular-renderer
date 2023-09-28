//
//  Ring.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/27/23.
//

import Foundation
import HDL
import QuaternionModule

public struct Ring {
  public var centers: [SIMD3<Float>]
  
  /// - Parameter radius: Approximate number of diagonal unit cells (`1.414 * 0.357` nanometers = 1 cell) from center to perimeter. This is not exact because of some internal implementation details.
  /// - Parameter perimeter: Number of crystal unit cells placed diagonally to generate the perimeter.
  /// - Parameter thickness: Thickness of the diamond rope in the XZ plane. Currently non-functional unless the value is `1.0`.
  /// - Parameter depth: Thickness of the diamond rope in the Y direction. Currently non-functional unless the value is `1.5`.
  /// - Parameter innerSpokes: Whether to include inner spokes, going from `r = 0` to `r = radius`.
  /// - Parameter outerSpokes: Whether to include outer spokes, going from `r = radius` to `r = 2 * radius`.
  public init(
    radius: Float,
    perimeter: Int,
    thickness: Float,
    depth: Float,
    innerSpokes: Bool,
    outerSpokes: Bool
  ) throws {
    struct _Error: LocalizedError {
      var description: String
    }
    guard perimeter % 4 == 0 else {
      throw _Error(description: "Perimeter not divisibe by 4.")
    }
    guard radius.remainder(dividingBy: 0.5) == 0 else {
      throw _Error(description: "Radius not divisibe by 0.5.")
    }
    let radiusSize = radius
    let perimeterSize1 = perimeter / 4
    let radius = try! DiamondRope(
      height: depth, width: thickness, length: Int(floor(radiusSize))).lattice
    let perimeter = try! DiamondRope(
      height: depth, width: thickness, length: perimeterSize1).lattice
    
    let segment = Solid { h, k, l in
      if innerSpokes {
        Copy { radius }
        Affine {
          Copy { radius }
          Translate {
            Float(radiusSize - floor(radiusSize)) * (h + l) }
        }
      }
      Affine {
        Copy { perimeter }
        Translate { -Float(perimeterSize1) / 2 * (h + l) }
        Rotate { 0.25 * k }
        Translate { Float(radiusSize) * (h + l) }
        Translate { 1.00 * (h + l) + 0.25 * (h - l) - 0.25 * k }
      }
      if outerSpokes {
        Affine {
          Copy { radius }
          Translate { Float(radiusSize) * (h + l) }
        }
        Affine {
          Copy { radius }
          Translate { Float(radiusSize) * (h + l) }
          Translate {
            Float(radiusSize - floor(radiusSize)) * (h + l) }
        }
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
            Translate { (depth - 1.5) * k }
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
      
      if distanceRad < Float(radiusSize) - thickness / 4 ||
          distanceRad > Float(radiusSize) + thickness / 4 {
        // rotate around axis, to the nearest multiple of 25 degrees
        let perimeterAdjusted = rint(4 * perimeterProportion) / 4
        let rotation = Quaternion(
          angle: perimeterAdjusted * 2 * Float.pi, axis: [0, 1, 0])
        
        var output = center
        output -= perimeterAdjusted * 4 * [1, 0, -1] * Float(perimeterSize)
        output = rotation.act(on: output)
        
        let targetY: Float = (
          Int(perimeterAdjusted * 4) % 2 == 0) ? -0.125 : 0.125
        output.y += targetY
        return output
      } else {
        // rotate around axis perfectly
        let angle = (perimeterProportion - 0.125) * 2 * Float.pi
        let x = distanceRad * cos(angle) * sqrt(2)
        let z = distanceRad * -sin(angle) * sqrt(2)
        var output = SIMD3(x, center.y, z)
        
        output.y += 0.125 * sin(2 * angle)
        
        return output
      }
    }
    
    centers = deduplicate(centers)
  }
}
