//
//  MRAtomProvider.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Foundation

public protocol MRAtomProvider {
  func atoms(time: MRTime) -> [SIMD4<Float>]
}

extension MRRenderer {
  public func setAtomProvider(_ provider: MRAtomProvider) {
    self.atomProvider = provider
  }
  
  public func setAtomColors(_ colors: [SIMD3<Float>]) {
    self.atomColors = colors
  }
  
  public func setAtomRadii(_ radii: [Float]) {
    self.atomRadii = radii
  }
}