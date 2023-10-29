//
//  Reflect.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Reflect {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    Compiler.global.performReflect(closure().simdValue)
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}
