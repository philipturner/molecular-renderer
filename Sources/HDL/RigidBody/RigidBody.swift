//
//  RigidBody.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/24/23.
//

/// Means to extract atom positions and atomic numbers.
public struct RigidBody {
  // atomicNumbers
  // bonds
  // positions
  // velocities
  
  // angularVelocity
  // linearVelocity
  // - setters redefine the atoms' velocities to have the provided average
  // - when reading from an MRSim on disk, getter returns the computed average
  // hydrogenMassRepartitioning -> default 1.0
  // - all rigid bodies entering an MM4 simulation must have the same HMR
  
  // init(solid:) -> materializes Solid topology
  // init(lattice:) -> materializes Lattice topology
  // private init(...) -> reduces code duplication between Lattice and Solid
}

// TODO: Add minimize(steps:) (with a default value for steps) to both RigidBody
// and Array<RigidBody>, document how to apply it to similar data structures.
