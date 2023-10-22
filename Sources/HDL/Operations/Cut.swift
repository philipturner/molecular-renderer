//
//  Cut.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Cut {
  @discardableResult
  public init() {
    Compiler.global.performCut()
  }
}
