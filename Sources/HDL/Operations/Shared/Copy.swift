//
//  Copy.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/24/23.
//

public struct Copy {
  @discardableResult
  public init(_ closure: () -> [Entity]) {
    switch GlobalScope.global {
    case .solid:
      fatalError("Not implemented yet for Solid.")
    case .topology:
      fatalError("Not implemented yet for Topology.")
    default:
      GlobalScope.throwUnrecognized(Self.self)
    }
  }
}
