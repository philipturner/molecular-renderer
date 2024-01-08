//
//  Chapter4_Figure3.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/28/23.
//

import Foundation
import MolecularRenderer

extension Nanosystems.Chapter4 {
  struct Figure3: NanosystemsFigure {
    var a: Diamondoid
    
    init() {
      let ccBondLength = Constants.bondLengths[[6, 6]]!.average
      
      var carbonCenters: [SIMD3<Float>] = [.zero]
      for i in 1..<8 {
        var delta: SIMD3<Float>
        if i % 2 == 0 {
          delta = sp3Delta(start: [+ccBondLength, 0, 0], axis: [0, 0, +1])
        } else {
          delta = sp3Delta(start: [-ccBondLength, 0, 0], axis: [0, 0, -1])
        }
        
        let origin = carbonCenters.last! + delta
        carbonCenters.append(origin)
      }
      
      let atoms = carbonCenters.map {
        MRAtom(origin: $0, element: 6)
      }
      self.a = Diamondoid(atoms: atoms)
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a]
    }
  }
}
