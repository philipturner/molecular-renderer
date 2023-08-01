//
//  Motion.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/30/23.
//

import Foundation
import MolecularRenderer
import simd

func rotationVectorField(
  angularSpeedInRadPerPs: Float,
  origin: SIMD3<Float>,
  axis: SIMD3<Float>
) -> (SIMD3<Float>) -> SIMD3<Float> {
  let rotation = simd_quatf(angle: .pi / 2, axis: axis)
  return { position in
    let delta = position - origin
    let radius = length(delta)
    var direction = normalize(delta)
    direction = simd_act(rotation, direction)
    
    let speed = angularSpeedInRadPerPs * radius
    return direction * speed
  }
}
