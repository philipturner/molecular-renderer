//
//  AtomProviders.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import HDL
import MolecularRenderer

// MARK: - MRAtom Interface with Array

struct ArrayAtomProvider: MRAtomProvider {
  var atoms: [MRAtom]
  
  init(_ atoms: [MRAtom]) {
    self.atoms = atoms
  }
  
  init(_ centers: [SIMD3<Float>]) {
    self.init(centers.map { MRAtom(origin: $0, element: 6)})
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    return atoms
  }
}

struct AnimationAtomProvider: MRAtomProvider {
  var frames: [[MRAtom]]
  
  init(_ frames: [[MRAtom]]) {
    self.frames = frames
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    if frames.count == 0 {
      return []
    }
    
    var frameID = time.absolute.frames
    frameID = min(frameID, frames.count - 1)
    return frames[frameID]
  }
}

struct MovingAtomProvider: MRAtomProvider {
  var atoms: [MRAtom]
  var velocity: SIMD3<Float>
  
  // Velocity is in nanometers per IRL second.
  init(_ atoms: [MRAtom], velocity: SIMD3<Float>) {
    self.atoms = atoms
    self.velocity = velocity
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    let delta = velocity * Float(time.absolute.seconds)
    return atoms.map {
      var copy = $0
      copy.origin += delta
      return copy
    }
  }
}

extension MRAtom {
  init(entity: HDL.Entity) {
    if entity.storage.w == 0 {
      self = MRAtom(origin: entity.position, element: 0)
      self.flags = 0x1
      return
    }
    
    self = MRAtom(
      origin: entity.position,
      element: UInt8(entity.storage.w))
  }
}
