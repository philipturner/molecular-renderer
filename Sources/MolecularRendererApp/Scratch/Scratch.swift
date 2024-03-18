// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test two-bit logic gates with full MD simulation. Verify that they work
// reliably at room temperature with the proposed actuation mechanism, at up
// to a 3 nm vdW cutoff. How long do they take to switch?
//
// This may require serializing long MD simulations to the disk for playback.
func createGeometry() -> [Entity] {
  let housing = Housing()
  return housing.topology.atoms
}

// A prototype of a logic rod without any knobs. The purpose is to aid in the
// setup of the apparatus.
struct RodSkeleton {
  var topology = Topology()
  
  init() {
    createLattice()
    passivate()
  }
  
  mutating func createLattice() {
    // This is one atom layer higher than the typical surface without bumps.
    // Therefore, skeletons of logic rods will physically overlap at switches.
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 30 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Passivates the surface and reorders atoms for optimized simulation.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .elemental(.carbon)
    reconstruction.topology = topology
    reconstruction.removePathologicalAtoms()
    reconstruction.createBulkAtomBonds()
    reconstruction.createHydrogenSites()
    reconstruction.resolveCollisions()
    reconstruction.createHydrogenBonds()
    topology = reconstruction.topology
    topology.sort()
  }
}

// A pair of housing cells, which creates two switches.
struct Housing {
  var topology = Topology()
  var anchors: Set<UInt32> = []
  
  init() {
    createLattice()
    
    // TODO: Mark corner carbons for holding in place during simulation.
  }
  
  // Create a maximally small housing, pushing the boundaries of what is stiff
  // enough to work at room temperature.
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 14 * h + 8 * k + 7 * l }
      Material { .elemental(.carbon) }
    }
    topology.insert(atoms: lattice.atoms)
  }
}
