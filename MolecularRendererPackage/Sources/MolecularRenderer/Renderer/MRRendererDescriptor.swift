//
//  MRRendererDescriptor.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import protocol Metal.MTLLibrary

public class MRRendererDescriptor {
  /// Required. The atom colors.
  ///
  /// Specified in order of atomic number, from neutronium to the largest
  /// supported element.
  public var elementColors: [SIMD3<Float>]?
  
  /// Required. The atomic radii.
  ///
  /// Specified in order of atomic number, from neutronium to the largest
  /// supported element.
  public var elementRadii: [Float]?
  
  /// Required. The pre-compiled shader library.
  public var library: MTLLibrary?
  
  /// Required. The width of the render target before upscaling.
  ///
  /// This must be divisible by 6.
  public var renderTargetSize: Int?
  
  public init() {
    
  }
}
