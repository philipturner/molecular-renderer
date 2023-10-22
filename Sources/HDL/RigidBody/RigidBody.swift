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
  // relativePositions
  // relativeVelocities
  // - stores positions/velocities in a local coordinate space, internally
  //   projects to the global space using rigid body transforms
  
  // centerOfMass, rotationalInertia
  // position, rotation
  // velocity, angularVelocity
  // hydrogenMassRepartitioning -> default 1.0
  // - all rigid bodies entering an MM4 simulation must have the same HMR
  // - set hydrogen mass repartitioning to a static property, only changes with
  //   a denotative `withHydrogenMassRepartitioning(...)`
  // - similar functionality for passivation: a private static property sets it
  //   to hydrogen, but can be overridden with a scope setting the passivation
  //   to a halogen
  
  // init(solid:) -> materializes Solid topology
  // init(lattice:) -> materializes Lattice topology
  // private init(...) -> reduces code duplication between Lattice and Solid
}
