//
//  Solid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

import Foundation

public struct Solid {
  
}

// Adds atoms to the scene, aligned with the crystal plane
public struct Copy {
  @discardableResult
  public init<T>(_ closure: () -> Lattice<T>) {
    
  }
  
  @discardableResult
  public init(_ closure: () -> Solid) {
    
  }
}
