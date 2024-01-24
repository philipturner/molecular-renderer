//
//  Scratch2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/19/24.
//

import Foundation
import HDL
import MM4
import Numerics

/*
 How to lay out the parts relative to each other:
 
 let logicHousing = LogicHousing(parity: false)
 var logicHousing2 = LogicHousing(parity: true)
 for i in logicHousing2.topology.atoms.indices {
   var position = logicHousing2.topology.atoms[i].position
   position = SIMD3(position.z, position.y, position.x)
   position.x += 0.3567 * 7.5
   logicHousing2.topology.atoms[i].position = position
 }
 
 var logicRod = LogicRod(length: 20)
 for i in logicRod.topology.atoms.indices {
   var position = logicRod.topology.atoms[i].position
   position = SIMD3(position.z, position.y, position.x)
   position += 0.3567 * SIMD3(3.0, 2.5, -3)
   position.x += 0.030
   position.y -= 0.050
   logicRod.topology.atoms[i].position = position
 }
 var logicRod2 = LogicRod(length: 30)
 for i in logicRod2.topology.atoms.indices {
   var position = logicRod2.topology.atoms[i].position
   position = SIMD3(position.z, position.y, position.x)
   position += 0.3567 * SIMD3(3.0, 2.5, -3)
   position.x += 0.030
   position.y -= 0.050
   
   position = SIMD3(position.z, position.y, position.x)
   position.y = 0.3567 * 10 - position.y
   logicRod2.topology.atoms[i].position = position
 }
 var logicRod3 = logicRod
 for i in logicRod3.topology.atoms.indices {
   var position = logicRod3.topology.atoms[i].position
   position.x += 0.3567 * 7.5
   logicRod3.topology.atoms[i].position = position
 }
 */

struct LogicRodDescriptor {
  /// The span of each intendation, or zone where knobs don't exist.
  ///
  /// Units are lonsdaleite unit cells.
  ///
  /// This is the gap between two knobs or nearby plateaus on the logic rod. It
  /// is larger than the span of the atomic layer at the bottom of the
  /// indentation.
  var indentations: [Range<Int>] = []
  
  /// The length (in lonsdaleite unit cells).
  var length: Int?
}

// A fundmental component of a computer.
// - May need customizable length or customizable sequence of knobs. ✅
// - Should be extensible to future variants with vdW connectors to a clock.
//   - Future member of 'LogicRodDescriptor'.
struct LogicRod {
  var topology = Topology()
  
  init(descriptor: LogicRodDescriptor) {
    createRod(descriptor: descriptor)
    passivateSurfaces()
  }
  
  mutating func createRod(descriptor: LogicRodDescriptor) {
    guard let length = descriptor.length else {
      fatalError("Logic rod not fully specified.")
    }
    
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { Float(length) * h + 2 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Convex {
          Origin { 1.9 * l }
          Plane { l }
        }
        for range in descriptor.indentations {
          Concave {
            Convex {
              Origin { Float(range.startIndex) * h }
              Plane { h }
            }
            Convex {
              Origin { 1.5 * h2k }
              Plane { h2k }
            }
            Convex {
              Origin { Float(range.endIndex) * h }
              Plane { -h }
            }
          }
        }
        Replace { .empty }
      }
    }
    topology.insert(atoms: lattice.atoms)
  }
  
  mutating func passivateSurfaces() {
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
