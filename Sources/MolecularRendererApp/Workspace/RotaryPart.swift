//
//  RotaryPart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/23/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct RotaryPartDescriptor {
  var cachePath: String?
}

// The radius spans from 1.33 nm to 2.73 nm. The outer radius is larger than
// the desired 2.00 nm. We can fix this some time later.
struct RotaryPart: GenericPart {
  var rigidBody: MM4RigidBody
  
  init(descriptor: RotaryPartDescriptor) {
    // Compile the lattice.
    let lattice = Self.createLattice()
    
    // Load the structure from disk.
    var cachedStructure: Topology?
    if let cachePath = descriptor.cachePath {
      let key = Self.hash(atoms: lattice.atoms)
      cachedStructure = Self.load(key: key, cachePath: cachePath)
    }
    
    // Assign the rigid body.
    if let cachedStructure {
      let topology = cachedStructure
      rigidBody = Self.createRigidBody(topology: topology)
    } else {
      let topology = Self.createTopology(lattice: lattice)
      rigidBody = Self.createRigidBody(topology: topology)
      
      // Run an energy minimization.
      minimize(bulkAtomIDs: [])
      
      // Save the structure to disk.
      if let cachePath = descriptor.cachePath {
        let key = Self.hash(atoms: lattice.atoms)
        save(key: key, cachePath: cachePath)
      }
    }
    
    // Set the center of mass to zero.
    rigidBody.centerOfMass = .zero
  }
  
  static func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 41 * h + 4 * h2k + 6 * l }
      Material { .checkerboard(.germanium, .carbon) }
      
      // Replace the bottom part with air.
      Volume {
        Origin { 2 * h2k }
        Plane { -h2k }
        Replace { .empty }
      }
      
      // Replace some atoms with carbon.
      Volume {
        Origin { 2.5 * h2k }
        Plane { -h2k }
        Replace { .atom(.carbon) }
      }
      Volume {
        Concave {
          Concave {
            Origin { 2.667 * h2k }
            Plane { -h2k }
          }
          Concave {
            Origin { 1.5 * l }
            Plane { l }
          }
          Concave {
            Origin { 4.5 * l }
            Plane { -l }
          }
        }
        Replace { .atom(.carbon) }
      }
      
      // Replace some atoms with germanium.
      Volume {
        Concave {
          Convex {
            Origin { 3.333 * h2k }
            Plane { h2k }
          }
          Convex {
            Convex {
              Origin { 1.5 * l }
              Plane { -l }
            }
            Convex {
              Origin { 4.5 * l }
              Plane { l }
            }
          }
        }
        Replace { .atom(.germanium) }
      }
      Volume {
        Origin { 3.5 * h2k }
        Plane { h2k }
        Replace { .atom(.germanium) }
      }
      
      Volume {
        Origin { 4 * h2k }
        Origin { 1 * l }
        Plane { 1 / 4 * h2k - 1 * l }
        Replace { .empty }
      }
      Volume {
        Origin { 4 * h2k }
        Origin { 4.75 * l }
        Plane { 1 / 4 * h2k + 1 * l }
        Replace { .empty }
      }
    }
  }
  
  static func createTopology(lattice: Lattice<Hexagonal>) -> Topology {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .checkerboard(.germanium, .carbon)
    do {
      var atoms = lattice.atoms
      atoms.sort { $0.position.x < $1.position.x }
      reconstruction.topology.insert(atoms: atoms)
    }
    reconstruction.compile()
    reconstruction.topology.sort()
    var topology = reconstruction.topology
    
    // Parameters here are in nm.
    let latticeConstant = Constant(.hexagon) {
      .checkerboard(.germanium, .carbon)
    }
    
    // The X coordinate in the original space is mapped onto θ = (0, 2π).
    // - X = 0 transforms into θ = 0.
    // - X = 'perimeter' transforms into θ = 2π.
    // - Other values of X are mapped into the angular coordinate with a linear
    //   transformation. Anything outside of the range will overshoot and
    //   potentially overlap another chunk of matter.
    let perimeter = Float(40) * latticeConstant
    
    for atomID in topology.atoms.indices {
      var atom = topology.atoms[atomID]
      var position = atom.position
      
      let θ = 2 * Float.pi * position.x / perimeter
      let r = position.y
      position.x = r * Float.cos(θ)
      position.y = r * Float.sin(θ)
      
      atom.position = position
      topology.atoms[atomID] = atom
    }
    
    topology = deduplicate(topology: topology)
    topology.sort()
    
    return topology
  }
}
