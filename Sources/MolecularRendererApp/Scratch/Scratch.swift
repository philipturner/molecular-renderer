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
  var driveWallDescriptor = DriveWallDescriptor()
  driveWallDescriptor.cellCount = 1
  var driveWall = DriveWall(descriptor: driveWallDescriptor)
  for atomID in driveWall.topology.atoms.indices {
    var atom = driveWall.topology.atoms[atomID]
    var position = atom.position
    
    // Set Y to either 0 or -2.5, to visualize ends of the clock cycle.
    position += SIMD3(-1.8, -2.5, -0.1)
    atom.position = position
    driveWall.topology.atoms[atomID] = atom
  }
  
  var housing = Housing()
  for atomID in housing.topology.atoms.indices {
    var atom = housing.topology.atoms[atomID]
    var position = atom.position
    position = SIMD3(position.z, position.y, position.x)
    
    // Shift the housing down by 2 cells, to match the extension in the Y
    // direction.
    // TODO: Add this change to System.
    position += SIMD3(0, -2 * 0.357, 0)
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
    position += SIMD3(0, 0.85, 0.9)
    atom.position = position
    rod.topology.atoms[atomID] = atom
  }
  
  var atoms: [Entity] = []
  atoms += driveWall.topology.atoms
  atoms += housing.topology.atoms
  atoms += rod.topology.atoms
  return atoms
}

struct DriveWallDescriptor {
  // How many consecutive rods to clock.
  //
  // Only 1 and 2 are accepted as valid values.
  var cellCount: Int?
}

struct DriveWall {
  var topology = Topology()
  
  init(descriptor: DriveWallDescriptor) {
    createLattice(descriptor: descriptor)
    passivate()
  }
  
  mutating func createLattice(descriptor: DriveWallDescriptor) {
    let allowedCellCounts: Set<Int> = [1, 2]
    guard let cellCount = descriptor.cellCount,
          allowedCellCounts.contains(cellCount) else {
      fatalError("Descriptor not complete.")
    }
    
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      
      // This must be floating-point to be compatible wth the compiler.
      let lDimension: Float
      if cellCount == 2 {
        lDimension = 10
      } else {
        lDimension = 6
      }
      
      Bounds { 4 * h + 10 * h2k + lDimension * l }
      Material { .checkerboard(.silicon, .carbon) }
      
      Volume {
        func createRodAGroove() {
          Concave {
            Origin { 1.25 * l }
            Plane { l }
            
            Origin { 1.9 * h }
            Plane { h }
            
            Origin { 3.0 * l }
            Plane { -l }
          }
        }
        
        func createRodBGroove() {
          Concave {
            Origin { 5.25 * l }
            Plane { l }
            
            Origin { 1.9 * h }
            Plane { h }
            
            Origin { 3.0 * l }
            Plane { -l }
          }
        }
        
        Concave {
          createRodAGroove()
          Convex {
            Origin { 1 * h2k }
            Plane { h2k }
          }
          Convex {
            Origin { 1.9 * h + 3.75 * h2k }
            Plane { -k + h }
          }
        }
        
        if cellCount == 2 {
          Concave {
            createRodBGroove()
            Convex {
              Origin { 1 * h2k }
              Plane { h2k }
            }
            Convex {
              Origin { 1.9 * h + 3.75 * h2k }
              Plane { -k + h }
            }
          }
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
