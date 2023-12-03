//
//  Translate.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Translate {
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    guard GlobalScope.global == .solid else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    fatalError("Not implemented.")
  }
}
