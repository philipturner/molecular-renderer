//
//  Copy.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/24/23.
//

/// Adds atoms from a previously designed object.
public struct Copy {
  private var centers: [SIMD3<Float>] = []
  
  @discardableResult
  public init<T>(_ closure: () -> Lattice<T>) {
    Compiler.global.performCopy(closure()._centers)
  }
  
  @discardableResult
  public init(_ closure: () -> Solid) {
    Compiler.global.performCopy(closure()._centers)
  }
  
  @discardableResult
  public init(_rawCenters: () -> [SIMD3<Float>]) {
    Compiler.global.performCopy(_rawCenters())
  }
}

