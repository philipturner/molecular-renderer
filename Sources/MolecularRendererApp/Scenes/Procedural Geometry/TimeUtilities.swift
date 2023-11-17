//
//  TimeUtilities.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/17/23.
//

import Foundation
import System

// For lack of a better place to put them, bridging functions for cross-platform
// time utilities will go here.

fileprivate let startTime = ContinuousClock.now

func cross_platform_media_time() -> Double {
  let duration = ContinuousClock.now.duration(to: startTime)
  let seconds = duration.components.seconds
  let attoseconds = duration.components.attoseconds
  return -(Double(seconds) + Double(attoseconds) * 1e-18)
}
