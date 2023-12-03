//
//  Transform.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/2/23.
//

public struct Transform {
  @discardableResult
  public init(_ closure: () -> Void) {
    guard GlobalScope.global == .solid else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    fatalError("Not implemented.")
  }
}
