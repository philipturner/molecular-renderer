//
//  Parts.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/18/24.
//

import Foundation
import HDL
import MM4

// A configuration for a logic rod.
struct RodDescriptor {
  // The number of unit cells to extend the rod to.
  //
  // This is currently an integer, because the actual termination pattern
  // likely can't be generated with the current API. Thus, a floating point
  // number would provide a false sense of control and scalability.
  var length: Int?
  
  // An HDL description of the knobs.
  var pattern: ((SIMD3<Float>, SIMD3<Float>, SIMD3<Float>) -> Void)?
}

// A logic rod.
struct Rod {
  var topology = Topology()
  
  init(descriptor: RodDescriptor) {
    createLattice(descriptor: descriptor)
  }
  
  mutating func createLattice(descriptor: RodDescriptor) {
    guard let length = descriptor.length,
          let pattern = descriptor.pattern else {
      fatalError("Descriptor not complete.")
    }
    
    // The default geometry is one atom layer higher than the typical surface
    // without bumps. Therefore, un-patterned logic rods physically overlap at
    // switches.
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      
      // Convert to floating-point to be compatible with the compiler.
      let hDimension = Float(length)
      
      Bounds { hDimension * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      #if false
      pattern(h, k, l)
      #endif
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
  }
  
  // Create a maximally small housing, pushing the boundaries of what is stiff
  // enough to work at room temperature.
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 13 * h + 10 * k + 7 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        func inputRodShaft() {
          Concave {
            Concave {
              Plane { h }
              Plane { k }
              Origin { 4 * h + 4.25 * k }
              Plane { -h }
              Plane { -k }
            }
            Convex {
              Origin { 0.25 * h + 0.25 * k }
              Plane { h + k }
            }
            Convex {
              Origin { 3.75 * h + 0.25 * k }
              Plane { -h + k }
            }
          }
        }
        
        Convex {
          Origin { 1.5 * h + 1.5 * k }
          inputRodShaft()
        }
        
        Convex {
          Origin { 7.5 * h + 1.5 * k }
          inputRodShaft()
        }
        
        // Create the output rod shaft.
        Convex {
          Origin { 1.5 * l + 4.25 * k }
          Concave {
            Concave {
              Plane { l }
              Plane { k }
              Origin { 4 * l + 4.25 * k }
              Plane { -l }
              Plane { -k }
            }
            Convex {
              Origin { 0.25 * l + 4.00 * k }
              Plane { l - k }
            }
            Convex {
              Origin { 3.75 * l + 4.00 * k }
              Plane { -l - k }
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
