//
//  Scope.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

public struct Affine {
  @discardableResult
  public init(_ closure: () -> Void) {
    
  }
}

public struct Volume {
  @discardableResult
  public init(_ closure: () -> Void) {
    LatticeStack.global.withScope(type: .volume) {
      closure()
    }
  }
}
