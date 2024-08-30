//
//  BVHBuilder+AtomCount.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 8/30/24.
//

extension BVHBuilder {
  /// Hard limit on the maximum atom count.
  static var maxAtomCount: Int {
    4 * 1024 * 1024
  }
}
