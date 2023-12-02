//
//  Origin.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Origin {
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    LatticeStack.touchGlobal()
    LatticeStack.global!.origin(delta: closure())
  }
}
