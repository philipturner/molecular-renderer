//
//  StructureUtilities.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import simd

let ccBondLength: Float = 0.154
let chBondLength: Float = 0.109
let ccBondLengthMax: Float = 0.170

let sp2BondAngle: Float = 120 * .pi / 180
let sp3BondAngle: Float = 109.5 * .pi / 180

func sp2Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  
  let rotation = simd_quatf(angle: sp2BondAngle / 2, axis: axis)
  return simd_act(rotation, start)
}

func sp3Delta(
  start: SIMD3<Float>, axis: SIMD3<Float>
) -> SIMD3<Float> {
  
  let rotation = simd_quatf(angle: sp3BondAngle / 2, axis: axis)
  return simd_act(rotation, start)
}
