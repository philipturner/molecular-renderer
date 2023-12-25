//
//  Chapter9_Figure8.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Foundation
import MolecularRenderer

extension Nanosystems.Chapter9 {
  struct Figure8: NanosystemsFigure {
    var a: Diamondoid
    
    init() {
      // Use OpenMM energy minimizations to warp a flat (111) diamond sheet
      // around the X axis.
      fatalError("Not implemented.")
    }
    
    var structures: [WritableKeyPath<Self, Diamondoid>] {
      [\.a]
    }
  }
}
