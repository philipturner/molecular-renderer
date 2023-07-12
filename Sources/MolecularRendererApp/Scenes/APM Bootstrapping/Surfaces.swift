//
//  Surfaces.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/11/23.
//

import Foundation
import MolecularRenderer
import simd

struct GoldSurface {
  var atoms: [MRAtom]
  
  init() {
    let spacing: Float = 0.40782
    let size = Int(16 / spacing)
    let cuboid = GoldCuboid(
      latticeConstant: spacing, plane: .fcc100(size, 3, size))
    self.atoms = cuboid.atoms
    
    for i in 0..<atoms.count {
      atoms[i].origin.y -= 1 * spacing
    }
  }
}
