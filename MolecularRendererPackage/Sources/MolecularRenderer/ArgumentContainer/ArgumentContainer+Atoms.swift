//
//  ArgumentContainer+Atoms.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/25/24.
//

extension ArgumentContainer {
  mutating func updateAtoms(provider: MRAtomProvider) {
    guard let currentTime else {
      fatalError("Time was not specified.")
    }
    
    let providerAtoms = provider.atoms(time: currentTime)
    guard providerAtoms.count > 0,
          providerAtoms.count < BVHBuilder.maxAtomCount else {
      fatalError("Atom count was invalid.")
    }
    
    currentAtoms = providerAtoms
  }
  
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

// MARK: - API

public protocol MRAtomProvider {
  func atoms(time: MRTime) -> [SIMD4<Float>]
}

extension MRRenderer {
  public func setAtomProvider(_ provider: MRAtomProvider) {
    self.atomProvider = provider
  }
}
