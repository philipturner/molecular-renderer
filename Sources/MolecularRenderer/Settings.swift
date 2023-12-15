//
//  Settings.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 7/13/23.
//

import Foundation

// A means to balance quality with performance.
//
// Disable fancy effects:
// - samples: 0...0
// - coefficient: 0
//
// Real-time global illumination:
// - samples: 3...7
// - coefficient: 30
//
// Offline production renders:
// - samples: 7...32
// - coefficient: 100
public struct MRQuality {
  public var minSamples: Int
  public var maxSamples: Int
  public var qualityCoefficient: Float
  
  @inlinable
  public init(
    minSamples: Int,
    maxSamples: Int,
    qualityCoefficient: Float
  ) {
    self.minSamples = minSamples
    self.maxSamples = maxSamples
    self.qualityCoefficient = qualityCoefficient
  }
}

public enum MRSceneSize {
  /// 0.25 nm grid cells, <1 million atoms
  case small
  
  /// 0.5 nm grid cells, <8 million atoms
  case large
  
  /// 0.5 nm grid cells, no limit on atom count, scene must be static
  case extreme
}
