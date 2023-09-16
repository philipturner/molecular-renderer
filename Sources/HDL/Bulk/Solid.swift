//
//  Solid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

import Foundation

public struct Solid {
  private var centers: [SIMD3<Float>] = []
  
  public init(_ closure: () -> Void) {
    
  }
}

// Adds atoms to the scene, aligned with the crystal plane
public struct Copy {
  private var centers: [SIMD3<Float>] = []
  
  @discardableResult
  public init<T>(_ closure: () -> Lattice<T>) {
    
  }
  
  @discardableResult
  public init(_ closure: () -> Solid) {
    
  }
}
