//
//  System.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/22/24.
//

import HDL
import MM4
import Numerics

struct System {
  var rod1: Rod
  var rod2: Rod
  var housing: Housing
  
  init() {
    // Create lattices for the logic rods.
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
    
    // Create the logic rods.
    rod1 = Rod(lattice: lattice1)
    rod2 = Rod(lattice: lattice2)
    
    // Create 'housing'.
    housing = Housing()
    
    // Bring the parts into their start position.
    alignParts()
  }
  
  mutating func alignParts() {
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
  }
}
