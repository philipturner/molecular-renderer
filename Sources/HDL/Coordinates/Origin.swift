//
//  Origin.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Origin {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    Compiler.global.moveOrigin(closure().simdValue)
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}
