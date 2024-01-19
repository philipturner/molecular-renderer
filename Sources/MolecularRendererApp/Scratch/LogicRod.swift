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

// A fundmental component of a computer.
// - May need customizable length or customizable sequence of knobs.
// - Should be extensible to future variants with vdW connectors to a clock.
struct LogicRod {
  var topology = Topology()
  
  init(length: Int) {
    createRod(length: length)
  }
  
  // Find a static rod thickness that's optimal for the entire system. Then,
  // make the rod length variable.
  mutating func createRod(length: Int) {
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { Float(length) * h + 2 * h2k + 4 * l }
      Material { .elemental(.carbon) }
      
      func cutGroove() {
        Concave {
          Convex {
            Plane { h }
          }
          Convex {
            Origin { 1.5 * h2k }
            Plane { h2k }
          }
          Convex {
            Origin { 6 * h }
            Plane { -h }
          }
        }
      }
      
      Volume {
        Convex {
          Origin { 1.9 * l }
          Plane { l }
        }
        Convex {
          Origin { -4 * h }
          cutGroove()
        }
        Convex {
          Origin { 7 * h }
          cutGroove()
        }
        Convex {
          Origin { 18 * h }
          cutGroove()
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
