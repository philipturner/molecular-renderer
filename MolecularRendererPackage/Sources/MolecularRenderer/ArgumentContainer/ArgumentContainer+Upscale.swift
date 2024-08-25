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
      print("true (0)")
      return true
    }
    
    if currentTime.absolute.frames == 0,
       currentTime.absolute.frames != previousTime.absolute.frames {
      print("true (1)")
      return true
    } else {
      print("false")
      return false
    }
  }
}
