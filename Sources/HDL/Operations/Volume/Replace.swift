//
//  Replace.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Replace {
  @discardableResult
  public init(_ closure: () -> EntityType) {
    LatticeStack.global.replace(with: closure().compactRepresentation)
  }
}
