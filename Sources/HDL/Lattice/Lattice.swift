//
//  Lattice.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/1/23.
//

public struct Lattice<T: Basis> {
  private var stack: LatticeStack
  
  public var entities: [Entity] { stack.grid.entities }

  public init(_ closure: (SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void) {
    // Check whether there is invalid syntax.
    guard LatticeStackDescriptor.global.basis == nil else {
      fatalError("Already set basis.")
    }
    guard let _T = T.self as? any _Basis.Type else {
      fatalError("Invalid basis type.")
    }
    LatticeStackDescriptor.global.basis = _T
    
    // Initialize the entities.
    GlobalScope.push(.lattice)
    closure(SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, 0, 1))
    guard GlobalScope.pop() == .lattice else {
      fatalError("Unexpected scope was popped.")
    }
    
    // Move ownership of the stack object this 'Lattice'.
    LatticeStack.touchGlobal()
    self.stack = LatticeStack.global!
    
    // Erase the global stack.
    LatticeStack.deleteGlobal()
  }
}
