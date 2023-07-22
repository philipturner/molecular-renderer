//
//  Figure3D.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import MolecularRenderer
import simd

protocol Figure3D: MRAtomProvider {
  var structures: [WritableKeyPath<Self, Diamondoid>] { get }
  var stackingDirection: SIMD3<Float> { get }
}

extension Figure3D {
  func atoms(time: MRTimeContext) -> [MRAtom] {
    var maxBoxSize: SIMD3<Float> = .zero
    let structures = self.structures
    for keyPath in structures {
      let box = self[keyPath: keyPath].boundingBox
      maxBoxSize = max(box[1] - box[0], maxBoxSize)
    }
    
    var direction: SIMD3<Float> = normalize(self.stackingDirection)
    precondition(
      abs(direction) == SIMD3(1, 0, 0) ||
      abs(direction) == SIMD3(0, 1, 0) ||
      abs(direction) == SIMD3(0, 0, 1),
      "Stacking direction needs to be aligned with an axis.")
    
    let minimumSpacing: Float = 0.1
    let spacing = (maxBoxSize + minimumSpacing) * direction
    
    // These offsets can be used directly to restore atom positions after a
    // batched OpenMM simulation. We can set up the simulation so atoms in
    // different structures don't interact with each other. Each structure's
    // position and overall momentum should not drift.
    var origins: [SIMD3<Float>] = [.zero]
    for _ in 1..<structures.count {
      let origin = origins.last! + spacing
      origins.append(origin)
    }
    var averageOrigin = origins.reduce(SIMD3<Float>.zero, +)
    averageOrigin /= Float(origins.count)
    origins = origins.map {
      $0 - averageOrigin
    }
    
    // Center the structures.
    var output: [MRAtom] = []
    for (i, keyPath) in structures.enumerated() {
      var atoms = self[keyPath: keyPath].atoms
      var averagePosition = atoms.reduce(SIMD3<Float>.zero) {
        $0 + $1.origin
      }
      
      averagePosition /= Float(atoms.count)
      averagePosition += origins[i]
      
      for i in atoms.indices {
        atoms[i].origin -= averagePosition
      }
      output.append(contentsOf: atoms)
    }
    return output
  }
}
