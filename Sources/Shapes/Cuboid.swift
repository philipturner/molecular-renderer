//
//  Cuboid.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

import HDL

// Outward facing cuboid (this can only be cut, not filled).
// TODO: Allow the user to specify an origin besides [0, 0, 0] and make the cube
// inside-out.
public struct Cuboid {
  public init(_ position: () -> Vector<Cubic>) {
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
