//
//  Scope.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

public struct Affine {
  @discardableResult
  public init(_ closure: () -> Void) {
    Compiler.global.startAffine()
    closure()
    Compiler.global.endAffine()
  }
}

public struct Volume {
  @discardableResult
  public init(_ closure: () -> Void) {
    Compiler.global.startVolume()
    closure()
    Compiler.global.endVolume()
  }
}
