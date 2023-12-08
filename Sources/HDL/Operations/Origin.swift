//
//  Origin.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Origin {
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    switch GlobalScope.global {
    case .lattice:
      LatticeStack.touchGlobal()
      LatticeStack.global!.origin(delta: closure())
    default:
      GlobalScope.throwUnrecognized(Self.self)
    }
  }
}
