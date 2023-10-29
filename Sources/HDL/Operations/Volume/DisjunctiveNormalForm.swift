//
//  DisjunctiveNormalForm.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Convex {
  @discardableResult
  public init(_ closure: () -> Void) {
    Compiler.global.startConvex()
    closure()
    Compiler.global.endConvex()
  }
}

public struct Concave {
  @discardableResult
  public init(_ closure: () -> Void) {
    Compiler.global.startConcave()
    closure()
    Compiler.global.endConcave()
  }
}
