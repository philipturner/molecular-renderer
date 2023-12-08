//
//  Copy.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/24/23.
//

public struct Copy {
  @discardableResult
  public init(_ closure: () -> [Entity]) {
    guard GlobalScope.global == .topology else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    fatalError("Not implemented.")
  }
}
