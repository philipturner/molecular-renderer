//
//  MRRendererDescriptor.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import protocol Metal.MTLLibrary

public class MRRendererDescriptor {
  /// Required. The width of the render target before upscaling.
  public var intermediateTextureSize: Int?
  
  /// Required. The pre-compiled shader library.
  public var library: MTLLibrary?
  
  /// Required. The upscale factor for temporal antialiased upscaling.
  public var upscaleFactor: Int?
  
  public init() {
    
  }
}
