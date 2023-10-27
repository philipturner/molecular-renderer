//
//  Lattice.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/1/23.
//

public struct Lattice<T: Basis> {
  private var stack: LatticeStack
  
  // This is currently a computed variable, but it may be cached in the future.
  public var entities: [Entity] { stack.grid.entities }

  public init(_ closure: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void) {
    // Check whether there is invalid syntax.
    guard LatticeStackDescriptor.global.basis == nil else {
      fatalError("Already set basis.")
    }
    LatticeStackDescriptor.global.basis = T.self
    
    // Initialize the entities.
    closure(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
    self.stack = LatticeStack.global!
    
    // Erase the global stack.
    LatticeStack.global = nil
  }
}
