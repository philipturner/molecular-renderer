//
//  Compiler.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import QuaternionModule

// MARK: - Environment Objects

private class Compiler {
  public let global: Compiler = Compiler()
  
  public init() {
    // Resets the scene after the popping the stack of the outermost
    // 'Solid' scope.
  }
}
