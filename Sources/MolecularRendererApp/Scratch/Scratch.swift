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
  var driveWall = DriveWall()
  for atomID in driveWall.topology.atoms.indices {
    var atom = driveWall.topology.atoms[atomID]
    var position = atom.position
    position += SIMD3(-2, 0, -0.1)
    atom.position = position
    driveWall.topology.atoms[atomID] = atom
  }
  
  var housing = Housing()
  for atomID in housing.topology.atoms.indices {
    var atom = housing.topology.atoms[atomID]
    var position = atom.position
    position = SIMD3(position.z, position.y, position.x)
    atom.position = position
    housing.topology.atoms[atomID] = atom
  }
  
  var rodDescriptor = RodDescriptor()
  rodDescriptor.length = 10
  rodDescriptor.pattern = { _, _, _ in
    
  }
  var rod = Rod(descriptor: rodDescriptor)
  for atomID in rod.topology.atoms.indices {
    var atom = rod.topology.atoms[atomID]
    var position = atom.position
    position += SIMD3(-0.5, 0.85, 0.9)
    atom.position = position
    rod.topology.atoms[atomID] = atom
  }
  
  var atoms: [Entity] = []
  atoms += driveWall.topology.atoms
  atoms += housing.topology.atoms
  atoms += rod.topology.atoms
  return atoms
}

struct DriveWall {
  var topology = Topology()
  
  init() {
    createLattice()
  }
  
  // This may require a list of patterns for the holes in the drive wall, and
  // a length variable. Do not store such a pattern in the same object as the
  // rod pattern. It might not require such an object at all, because the
  // pattern is not reconfigurable. Just hard-code it into 'System.init'.
  mutating func createLattice() {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 4 * h + 8 * h2k + 10 * l }
      Material { .checkerboard(.silicon, .carbon) }
      
      Volume {
        Concave {
          Origin { 1.25 * l }
          Plane { l }
          
          Origin { 1.9 * h }
          Plane { h }
          
          Origin { 3.0 * l }
          Plane { -l }
        }
        
        Concave {
          Origin { 5.25 * l }
          Plane { l }
          
          Origin { 1.9 * h }
          Plane { h }
          
          Origin { 3.0 * l }
          Plane { -l }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  // Passivates the surface and reorders atoms for optimized simulation.
  mutating func passivate() {
    var reconstruction = SurfaceReconstruction()
    reconstruction.material = .checkerboard(.silicon, .carbon)
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
