// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

// Test whether switches with sideways knobs work correctly. Test every
// possible permutation of touching knobs and approach directions.
//
// Then, test whether extremely long rods work correctly.
//
// Notes:
// - Save each test to rod-logic in its own file. Then, overwrite the contents
//   and proceed with the next test.
// - Run each setup with MD at room temperature.
func createGeometry() -> [Entity] {
  let lattice1 = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      // Create a sideways groove.
      Concave {
        Origin { 7 * h }
        Plane { h }
        
        Origin { 1.375 * l }
        Plane { l }
        
        Origin { 6 * h }
        Plane { -h }
      }
      Replace { .empty }
      
      // Create silicon dopants to stabilize the groove.
      Concave {
        Origin { 7 * h }
        Plane { h }
        Origin { 1 * h }
        Plane { -h }
        
        Origin { 1 * l }
        Plane { l }
        Origin { 0.5 * l }
        Plane { -l }
        
        Origin { 1 * h2k }
        Plane { -h2k }
      }
      Concave {
        Origin { (7 + 5) * h }
        Plane { h }
        Origin { 1 * h }
        Plane { -h }
        
        Origin { 1 * l }
        Plane { l }
        Origin { 0.5 * l }
        Plane { -l }
        
        Origin { 1 * h2k }
        Plane { -h2k }
      }
      Replace { .atom(.silicon) }
    }
  }
  let lattice2 = Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      // Create a sideways groove.
      Concave {
        Origin { 7 * h }
        Plane { h }
        
        Origin { 0.5 * l }
        Plane { -l }
        
        Origin { 6 * h }
        Plane { -h }
      }
      Replace { .empty }
      
      // Create silicon dopants to stabilize the groove.
      Concave {
        Origin { 7 * h }
        Plane { h }
        Origin { 1 * h }
        Plane { -h }
        
        Origin { 0.6 * l }
        Plane { -l }
        Origin { -0.5 * l }
        Plane { l }
        
        Origin { 1 * h2k }
        Plane { -h2k }
      }
      Concave {
        Origin { (7 + 5) * h }
        Plane { h }
        Origin { 1 * h }
        Plane { -h }
        
        Origin { 0.6 * l }
        Plane { -l }
        Origin { -0.5 * l }
        Plane { l }
        
        Origin { 1 * h2k }
        Plane { -h2k }
      }
      Replace { .atom(.silicon) }
    }
  }
  var rod1 = Rod(lattice: lattice1)
  var rod2 = Rod(lattice: lattice2)
  
  for atomID in rod1.topology.atoms.indices {
    var atom = rod1.topology.atoms[atomID]
    var position = atom.position
    position = SIMD3(position.z, position.y, position.x)
    position += SIMD3(0.91, 0.85, -1.25)
    atom.position = position
    rod1.topology.atoms[atomID] = atom
  }
  for atomID in rod2.topology.atoms.indices {
    var atom = rod2.topology.atoms[atomID]
    var position = atom.position
    position = SIMD3(position.z, position.y, position.x)
    position = SIMD3(position.x, position.z, position.y)
    
    let latticeConstant = Constant(.square) { .elemental(.carbon) }
    position += SIMD3(2.5 * latticeConstant, 0, 0)
    position += SIMD3(0.91, -1.25, 0.85)
    atom.position = position
    rod2.topology.atoms[atomID] = atom
  }
  
  let housing = Housing()
  
  var atoms: [Entity] = []
//  atoms += rod1.topology.atoms
//  atoms += rod2.topology.atoms
  atoms += housing.topology.atoms
  return atoms
}

struct Housing {
  var topology = Topology()
  
  init() {
    createLattice()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 8 * k + 8 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Groove for the first rod.
        Convex {
          Concave {
            Origin { 1.5 * h + 1.5 * k }
            Plane { h }
            Plane { k }
            Origin { 4 * h + 4.25 * k }
            Plane { -h }
            Plane { -k }
          }
          Convex {
            Origin { 7.25 * k }
            Plane { k }
          }
        }
        
        // Groove for the second rod.
        Convex {
          Origin { 2.5 * h }
          Concave {
            Concave {
              Origin { 1.5 * h + 1.5 * l }
              Plane { h }
              Plane { l }
              Origin { 4 * h + 4.25 * l }
              Plane { -h }
              Plane { -l }
            }
          }
          Convex {
            Origin { 7.25 * l }
            Plane { l }
          }
        }
        
        // Clean up the extraneous block of atoms on the right.
        Convex {
          Origin { 9.5 * h }
          Plane { h }
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
}

struct Rod {
  var topology = Topology()
  
  init(lattice: Lattice<Hexagonal>) {
    topology.insert(atoms: lattice.atoms)
    passivate()
  }
  
  // Adds hydrogens and reorders the atoms for efficient simulation.
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
