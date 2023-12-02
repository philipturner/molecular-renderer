//
//  Volume.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/2/23.
//

public struct Volume {
  @discardableResult
  public init(_ closure: () -> Void) {
    LatticeStack.touchGlobal()
    LatticeStack.global!.withScope(type: .volume) {
      closure()
    }
  }
}
