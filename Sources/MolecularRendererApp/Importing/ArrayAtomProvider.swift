//
//  ListAtomProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/21/23.
//

import Foundation
import MolecularRenderer

struct ArrayAtomProvider: MRAtomProvider {
  var atoms: [MRAtom]
  
  init(_ atoms: [MRAtom]) {
    self.atoms = atoms
  }
  
  init(_ centers: [SIMD3<Float>]) {
    self.init(centers.map { MRAtom(origin: $0, element: 6)})
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    return atoms
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
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    let delta = velocity * Float(time.absolute.seconds)
    return atoms.map {
      var copy = $0
      copy.origin += delta
      return copy
    }
  }
}
