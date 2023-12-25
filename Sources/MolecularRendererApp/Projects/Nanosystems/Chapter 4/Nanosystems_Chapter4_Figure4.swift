//
//  Chapter4_Figure4.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/28/23.
//

import Foundation
import MolecularRenderer

extension Nanosystems.Chapter4 {
  struct Figure4: NanosystemsFigure {
    var a: Diamondoid
    
    init() {
      let ccBondLength = Constants.bondLengths[[6, 6]]!.average
      
      let atoms: [MRAtom] = (0..<8).map { i in
        let x = i % 2
        let y = (i / 2) % 2
        let z = (i / 2) / 2
        let delta = SIMD3<Float>(SIMD3(x, y, z)) * ccBondLength
        return MRAtom(origin: delta, element: 6)
      }
      self.a = Diamondoid(atoms: atoms)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a]
    }
  }
}
