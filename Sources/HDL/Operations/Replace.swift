//
//  Replace.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Replace {
  @discardableResult
  public init(_ closure: () -> EntityType) {
    guard GlobalScope.global == .lattice else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    LatticeStack.touchGlobal()
    LatticeStack.global!.replace(with: closure().compactRepresentation)
  }
}
