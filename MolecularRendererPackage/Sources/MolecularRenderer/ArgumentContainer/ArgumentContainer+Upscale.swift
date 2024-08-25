//
//  ArgumentContainer+Upscale.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension ArgumentContainer {
  var useAtomMotionVectors: Bool {
    guard let currentTime else {
      fatalError("Current time was not specified")
    }
    if currentTime.absolute.frames > 0,
       currentTime.relative.frames > 0,
       currentAtoms.count == previousAtoms.count {
      return true
    } else {
      return false
    }
  }
  
  var resetUpscaler: Bool {
    guard let currentTime else {
      fatalError("Current time was not specified.")
    }
    guard let previousTime else {
      return true
    }
    
    if currentTime.absolute.frames == 0,
       currentTime.absolute.frames != previousTime.absolute.frames {
      return true
    } else {
      return false
    }
  }
}
