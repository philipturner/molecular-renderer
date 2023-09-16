//
//  Bounds.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/16/23.
//

public struct Bounds {
  @discardableResult
  public init(_ position: () -> Vector<Cubic>) {
    // Initialize the atoms to a cuboid.
    let vector = position()
    guard let x = Int32(exactly: vector.simdValue.x),
          let y = Int32(exactly: vector.simdValue.y),
          let z = Int32(exactly: vector.simdValue.z) else {
      fatalError("Bounds must be integer quantities of crystal unit cells.")
    }
    guard x > 0, y > 0, z > 0 else {
      fatalError("Bounds must be positive.")
    }
    Compiler.global.setBounds(SIMD3(x, y, z))
  }
  
  @discardableResult
  public init(_ position: () -> Vector<Hexagonal>) {
    // Initialize the atoms to a hexagonal prism.
    fatalError("Not implemented.")
  }
}
