//
//  Motion.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/30/23.
//

import Foundation
import MolecularRenderer
import QuaternionModule

func rotationVectorField(
  angularSpeedInRadPerPs: Float,
  origin: SIMD3<Float>,
  axis: SIMD3<Float>
) -> (SIMD3<Float>) -> SIMD3<Float> {
  let rotation = Quaternion<Float>(angle: .pi / 2, axis: axis)
  return { position in
    let delta = position - origin
    let radius = cross_platform_length(delta)
    var direction = cross_platform_normalize(delta)
    direction = rotation.act(on: direction)
    
    let speed = angularSpeedInRadPerPs * radius
    return direction * speed
  }
}
