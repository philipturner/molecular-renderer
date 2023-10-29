//
//  Translate.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/29/23.
//

public struct Translate {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    Compiler.global.performTranslate(closure().simdValue)
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}
