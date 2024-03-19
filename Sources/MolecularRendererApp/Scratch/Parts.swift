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
  var velocities: [SIMD3<Float>]?
  
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
      
      Volume {
        Convex {
          Origin { 1 * h2k }
          Plane { k - h }
        }
        Replace { .empty }
      }
      
      #if true
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
  var velocities: [SIMD3<Float>]?
  
  init() {
    createLattice()
  }
  
  // Create a maximally small housing, pushing the boundaries of what is stiff
  // enough to work at room temperature.
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      // The minimum required height is 10 * k. However, to be compatible
      // with the clocking mechanism, we extend this by ~2 cells in each
      // direction. If multiple bits were being clocked in parallel, this
      // extension would not be needed.
      Bounds { 13 * h + 17 * k + 7 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Shape a place on the bottom, to hold the input drive wall in place.
        Concave {
          Convex {
            Origin { 3 * k }
            Plane { -k }
          }
          Convex {
            Origin { 0 * k }
            Origin { 1 * l }
            Plane { -k + l }
          }
        }
        
        // Shape a place on the top, to hold the output drive wall in place.
        Concave {
          Convex {
            Origin { 14 * k }
            Plane { k }
          }
          Convex {
            Origin { 17 * k }
            Origin { 1 * h }
            Plane { h + k }
          }
        }
        
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
          Origin { 1.5 * h + 5.5 * k }
          inputRodShaft()
        }
        
        Convex {
          Origin { 7.5 * h + 5.5 * k }
          inputRodShaft()
        }
        
        // Create the output rod shaft.
        Convex {
          Origin { 1.5 * l + 8.25 * k }
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

struct DriveWallDescriptor {
  // How many consecutive rods to clock.
  //
  // Only 1 and 2 are accepted as valid values.
  var cellCount: Int?
}

struct DriveWall {
  var topology = Topology()
  var velocities: [SIMD3<Float>]?
  
  init(descriptor: DriveWallDescriptor) {
    createLattice(descriptor: descriptor)
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
      
      Bounds { 4 * h + 8 * h2k + lDimension * l }
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
            Origin { 1.9 * h + 2.75 * h2k }
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
              Origin { 1.9 * h + 2.75 * h2k }
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
