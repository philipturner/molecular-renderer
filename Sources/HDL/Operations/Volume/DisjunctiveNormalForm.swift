//
//  DisjunctiveNormalForm.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

// A pair of keywords for disjunctive normal form on planes.

public struct Convex {
  @discardableResult
  public init(_ closure: () -> Void) {
    LatticeStack.touchGlobal()
    LatticeStack.global!.withScope(type: .convex) {
      closure()
    }
  }
}

public struct Concave {
  @discardableResult
  public init(_ closure: () -> Void) {
    LatticeStack.touchGlobal()
    LatticeStack.global!.withScope(type: .concave) {
      closure()
    }
  }
}
