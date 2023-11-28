//
//  MRAtom+Extensions.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/27/23.
//

import HDL
import MolecularRenderer

extension MRAtom {
  init(entity: HDL.Entity) {
    if case .empty = entity.type {
      self = MRAtom(origin: entity.position, element: 0)
      self.flags = 0x1
      return
    }
    
    guard case .atom(let element) = entity.type else {
      fatalError("Unrecognized entity type: \(entity.storage.w)")
    }
    self = MRAtom(
      origin: entity.position,
      element: element.rawValue)
  }
}
