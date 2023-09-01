//
//  Basis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public protocol Basis {
  
}

public struct Cubic: Basis {
  
}

public struct Hexagonal: Basis {
  
}

public struct Bounds {
  @discardableResult
  public init(_ position: () -> Position<Cubic>) {
    // Initialize the atoms to a cuboid.
  }
  
  @discardableResult
  public init(_ position: () -> Position<Hexagonal>) {
    // Initialize the atoms to a hexagonal prism.
  }
}