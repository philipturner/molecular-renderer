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
  
  /// Optional. Whether to use a mode that decreases render stage performance,
  /// to improve geometry stage performance.
  ///
  /// The default value optimizes performance for small systems.
  public var sceneSize: MRSceneSize = .small
  
  /// Optional. Whether to print a space-separated list of microsecond latencies
  /// for each stage of the render pipeline.
  public var reportPerformance: Bool = false
  
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

public enum MRSceneSize {
  /// 0.25 nm grid cells, <1 million atoms
  /// - cheapest per-pixel cost
  /// - highest per-atom cost
  case small
  
  /// 0.5 nm grid cells, <8 million atoms
  /// - higher per-pixel cost
  /// - cheaper per-atom cost
  case large
  
  /// 0.5 nm grid cells, no limit on atom count, scene must be static
  /// - highest per-pixel cost
  /// - zero per-atom cost
  /// - volume becomes a bottleneck (primary ray intersects too many cells)
  case extreme
}
