//
//  Origin.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Origin {
  @discardableResult
  public init(_ closure: () -> Vector<Cubic>) {
    // For operations like this one, there needs to be a global object that
    // tracks which scope is being affected. If it's a lattice scope, you need
    // to delegate to 'LatticeStack'. Otherwise, delegate to 'SolidStack'.
  }
  
  @discardableResult
  public init(_ closure: () -> Vector<Hexagonal>) {
    fatalError("Not implemented.")
  }
}
