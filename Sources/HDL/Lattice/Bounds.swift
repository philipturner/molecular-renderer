//
//  Bounds.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/16/23.
//

public struct Bounds {
  @discardableResult
  public init(_ closure: () -> SIMD3<Float>) {
    let bounds = closure()
    let remainder = bounds - bounds.rounded(.down)
    guard all(remainder .== 0) else {
      fatalError("Bounds were not integers.")
    }
    
    guard LatticeStackDescriptor.global.bounds == nil else {
      fatalError("Already set bounds.")
    }
    LatticeStackDescriptor.global.bounds = bounds
  }
}
