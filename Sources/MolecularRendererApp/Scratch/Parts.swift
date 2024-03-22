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
      Bounds { 10 * h + 8 * k + 8 * l }
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
              Origin { 4 * h + 4.25 * l }
              Plane { -h }
              Plane { -l }
            }
            
            // Fill in some places where the bonding topology is ambiguous.
            Convex {
              Origin { 0.25 * h + 0.25 * l }
              Plane { h + l }
            }
            Convex {
              Origin { 3.75 * h + 0.25 * l }
              Plane { -h + l }
            }
          }
          
          // Clean up the extraneous block of atoms on the front.
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
