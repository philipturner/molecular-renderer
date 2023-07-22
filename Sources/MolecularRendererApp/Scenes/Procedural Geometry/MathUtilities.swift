//
//  MathUtilities.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import simd

func sp3Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  let sp3BondAngle: Float = 109.5 * .pi / 180
  let rotation = simd_quatf(angle: sp3BondAngle / 2, axis: axis)
  return simd_act(rotation, start)
}
