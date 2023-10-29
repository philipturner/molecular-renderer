//
//  Chapter12_Figure1.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

import Foundation
import HDL
import MolecularRenderer

extension Nanosystems.Chapter12 {
  // This figure will be a picture-perfect reproduction of Figure 1. The
  // simulation will be hosted in another stored property. The stacking
  // direction must be vertical to match the MIT thesis.
  struct Figure1/*: Figure3D*/ {
//    var a: Diamondoid
//    var b: Diamondoid
//    var c: Diamondoid
    var provider: any MRAtomProvider
    
    init() {
      let atom = MRAtom(origin: .zero, element: 6)
      provider = ArrayAtomProvider([atom])
    }
  }
}
