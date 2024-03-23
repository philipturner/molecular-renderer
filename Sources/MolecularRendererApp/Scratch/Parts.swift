//
//  Parts.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/22/24.
//

import HDL
import MM4
import Numerics

struct Housing {
  var topology = Topology()
  
  init() {
    createLattice()
    passivate()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 10 * h + 8 * k + 7 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Groove for the first rod.
        Convex {
          Concave {
            Origin { 1.5 * h + 1.5 * k }
            
            // Create the actual groove.
            Concave {
              Plane { h }
              Plane { k }
              Origin { 4 * h + 4.25 * k }
              Plane { -h }
              Plane { -k }
            }
            
            // Fill in some places where the bonding topology is ambiguous.
            Convex {
              Origin { 0.25 * h + 0.25 * k }
              Plane { h + k }
            }
            Convex {
              Origin { 3.75 * h + 0.25 * k }
              Plane { -h + k }
            }
          }
          
          // Clean up the extraneous block of atoms on the top.
          Convex {
            Origin { 7.25 * k }
            Plane { k }
          }
        }
        
        // Groove for the second rod.
        Convex {
          Origin { 2.5 * h }
          Concave {
            Origin { 1.5 * h + 1.5 * l }
            
            // Create the actual groove.
            Concave {
              Plane { h }
              Plane { l }
              Origin { 4.25 * h + 4 * l }
              Plane { -h }
              Plane { -l }
            }
            
            Convex {
              Origin { 0.25 * h + 0.25 * l }
              Plane { h + l }
            }
            Convex {
              Origin { 0.25 * h + 3.75 * l }
              Plane { h - l }
            }
          }
        }
        
        // Clean up the extraneous block of atoms on the right.
        Convex {
          Origin { 9.75 * h }
          Plane { h }
        }
        
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
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

// MARK: - Instantiating Parts

func createRod1Lattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
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
}

func createRod2Lattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 2 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      // Create a vertical groove.
      Concave {
        Origin { 7 * h }
        Plane { h }
        
        Origin { 1.5 * h2k }
        Plane { h2k }
        
        Origin { 6 * h }
        Plane { -h }
      }
      Replace { .empty }
    }
  }
}
