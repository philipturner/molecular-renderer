//
//  Filter.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/2/23.
//

public struct Filter {
  @discardableResult
  public init(_ closure: () -> Void) {
    guard GlobalScope.global == .topology else {
      GlobalScope.throwUnrecognized(Self.self)
    }
    fatalError("Not implemented.")
  }
}
