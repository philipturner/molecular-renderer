//
//  DisjunctiveNormalForm.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Convex {
  @discardableResult
  public init(_ closure: () -> Void) {
    LatticeStack.global.withScope(type: .convex) {
      closure()
    }
  }
}

public struct Concave {
  @discardableResult
  public init(_ closure: () -> Void) {
    LatticeStack.global.withScope(type: .concave) {
      closure()
    }
  }
}
