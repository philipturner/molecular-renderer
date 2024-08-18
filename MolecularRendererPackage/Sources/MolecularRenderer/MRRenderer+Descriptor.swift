//
//  MRRendererDescriptor.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation

public class MRRendererDescriptor {
  /// Required. Location of the MolecularRendererGPU binary.
  public var url: URL?
  
  /// Required. Width of the render target after upscaling.
  public var width: Int?
  
  /// Required. Height of the render target after upscaling.
  public var height: Int?
  
  /// Optional. Ignored in the offline mode, which instead downscales 2x.
  public var upscaleFactor: Int = 1
  
  /// Optional. A mode with unacceptable performance in real-time, but which can
  /// reliably produce renders at a low resolution. MolecularRenderer is not
  /// optimized for production rendering, only real-time rendering. However, it
  /// can do production rendering, which this mode is for.
  public var offline: Bool = false
  
  /// Optional. Whether to print a space-separated list of microsecond latencies
  /// for each stage of the render pipeline.
  public var reportPerformance: Bool = false
  
  /// Optional. Whether to incorporate animated atom positions into motion
  /// vectors for temporal upscaling.
  ///
  /// The default value is `true`.
  ///
  /// If the number of atoms changes during a frame, motion vectors are
  /// automatically disabled.
  public var useMotionVectors: Bool = true
  
  public init() {
    
  }
  
  func assertValid() {
    guard url != nil,
          width != nil,
          height != nil else {
      fatalError("'MRRendererDescriptor' not complete.")
    }
  }
}
