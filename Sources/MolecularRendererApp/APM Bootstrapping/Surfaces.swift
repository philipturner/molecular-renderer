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
    var plane: [MRAtom] = []
    let spacing: Float = 0.40782
    let size = Int(8 / spacing)
    for x in -size..<size {
      for z in -size..<size {
        let coords = SIMD3<Int>(x, 0, z)
        plane.append(MRAtom(
          origin: spacing * SIMD3(coords), element: 79))
      }
    }
    atoms = plane
    
    let offsets: [SIMD3<Float>] = [
      SIMD3(spacing / 2, -spacing / 2, 0),
      SIMD3(0, -spacing / 2, spacing / 2),
      SIMD3(spacing / 2, 0, spacing / 2),
    ]
    for offset in offsets {
      atoms += plane.map { input in
        var atom = input
        atom.origin += offset
        return atom
      }
    }
    
    var newAtoms = atoms
    for y in -2..<0 {
      newAtoms += atoms.map { input in
        var atom = input
        atom.origin.y += Float(y) * spacing
        return atom
      }
    }
    self.atoms = newAtoms
  }
}
