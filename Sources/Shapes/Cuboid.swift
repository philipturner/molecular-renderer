//
//  Cuboid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

import HDL

// Outward facing cuboid (this can only be cut, not filled).
public struct Cuboid {
  public init(_ position: () -> Position<Cubic>) {
    Convex {
      for axis in [x, y, z] {
        Plane { -axis }
      }
      Origin { position() }
      for axis in [x, y, z] {
        Plane { +axis }
      }
    }
  }
}
