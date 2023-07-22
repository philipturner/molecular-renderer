//
//  ListAtomProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import Foundation
import MolecularRenderer

struct ArrayAtomProvider: MRAtomProvider {
  var atoms: [MRAtom]
  
  init(_ atoms: [MRAtom]) {
    self.atoms = atoms
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    return atoms
  }
}
