//
//  Figure3D.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/22/23.
//

import Foundation
import MolecularRenderer

protocol NanosystemsFigure: MRAtomProvider {
  var structures: [WritableKeyPath<Self, Diamondoid>] { get }
  var stackingDirection: SIMD3<Float> { get }
}

extension NanosystemsFigure {
  var stackingDirection: SIMD3<Float> {
    SIMD3(0, -1, 0)
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    // These origins can be used directly to restore atom positions after a
    // batched OpenMM simulation. We can set up the simulation so atoms in
    // different structures don't interact with each other. Each structure's
    // position and overall momentum should not drift.
    var origins: [SIMD3<Float>] = [.zero]
    func getSize(_ structure: Diamondoid) -> SIMD3<Float> {
      let boundingBox = structure.createBoundingBox()
      return boundingBox.1 - boundingBox.0
    }
    
    let structures = self.structures
    var previousSize: SIMD3<Float> = getSize(self[keyPath: structures[0]])
    let direction: SIMD3<Float> = cross_platform_normalize(self.stackingDirection)
    precondition(
      cross_platform_abs(direction) == SIMD3<Float>(1, 0, 0) ||
      cross_platform_abs(direction) == SIMD3<Float>(0, 1, 0) ||
      cross_platform_abs(direction) == SIMD3<Float>(0, 0, 1),
      "Stacking direction needs to be aligned with an axis.")
    
    let spacing = 0.1 * direction
    for i in 1..<structures.count {
      var delta = direction * (previousSize * 0.5)
      previousSize = getSize(self[keyPath: structures[i]])
      delta += direction * (previousSize * 0.5)
      delta += spacing
      origins.append(origins.last! + delta)
    }
    
    let averageOrigin = (origins.first! + origins.last!) / 2
    origins = origins.map { $0 - averageOrigin }
    
    // Center the structures.
    var output: [MRAtom] = []
    for (i, keyPath) in structures.enumerated() {
      let box = self[keyPath: keyPath].createBoundingBox()
      let boxCenter = (box.0 + box.1) / 2
      let translation = origins[i] - boxCenter
      
      var atoms = self[keyPath: keyPath].atoms
      for index in atoms.indices {
        atoms[index].origin += translation
      }
      output.append(contentsOf: atoms)
    }
    return output
  }
}
