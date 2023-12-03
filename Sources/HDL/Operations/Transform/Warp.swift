//
//  Warp.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 11/28/23.
//

public struct Warp {
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    guard GlobalScope.global == .solid else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    fatalError("Not implemented.")
  }
}
