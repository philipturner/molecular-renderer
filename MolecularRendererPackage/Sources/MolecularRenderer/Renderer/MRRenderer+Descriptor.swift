//
//  MRRendererDescriptor.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation

public class MRRendererDescriptor {
  /// Required. The width of the render target before upscaling.
  public var intermediateTextureSize: Int?
  
  /// Optional. Whether to print a space-separated list of microsecond latencies
  /// for each stage of the render pipeline.
  public var reportPerformance: Bool = false
  
  /// Required. The upscale factor for temporal antialiased upscaling.
  public var upscaleFactor: Int?
  
  /// Required. Location of the pre-compiled shader library.
  ///
  /// TODO: Replace with the shader library object.
  public var url: URL?
  
  public init() {
    
  }
}
