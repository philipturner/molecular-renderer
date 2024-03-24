//
//  Knob.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

// A snippet of HDL that specifies a rod's pattern.
// - inputs: h, h2k, l
// - scope: called inside a 'Volume'
typealias KnobPattern = (
  SIMD3<Float>, SIMD3<Float>, SIMD3<Float>
) -> Void
