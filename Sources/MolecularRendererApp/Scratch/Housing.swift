//
//  Housing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/23/24.
//

import Foundation
import HDL
import MM4
import Numerics

import QuartzCore

struct Housing {
  var topology = Topology()
  
  init() {
    createLattice()
    passivate()
  }
  
  mutating func createLattice() {
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 48 * h + 28 * k + 35 * l }
      Material { .elemental(.carbon) }
      
      func fillInCorner(majorAxis: SIMD3<Float>, minorAxis: SIMD3<Float>) {
        Convex {
          Origin { 0.25 * majorAxis + 0.25 * minorAxis }
          Plane { majorAxis + minorAxis }
        }
        Convex {
          Origin { 0.25 * majorAxis + 4.00 * minorAxis }
          Plane { majorAxis - minorAxis }
        }
        Convex {
          Origin { 3.75 * majorAxis + 0.25 * minorAxis }
          Plane { -majorAxis + minorAxis }
        }
        Convex {
          Origin { 3.75 * majorAxis + 4.00 * minorAxis }
          Plane { -majorAxis - minorAxis }
        }
      }
      
      func createHoleX(offset: SIMD3<Float>) {
        Concave {
          Origin { offset[0] * h + offset[1] * k + offset[2] * l }
          Origin { 1.5 * k + 1.5 * l }
          
          // Create a groove for the rod.
          Concave {
            Plane { k }
            Plane { l }
            Origin { 4.25 * k + 4 * l }
            Plane { -k }
            Plane { -l }
          }
          
          // Fill in some places where the bonding topology is ambiguous.
          fillInCorner(majorAxis: l, minorAxis: k)
        }
      }
      
      func createHoleY(offset: SIMD3<Float>) {
        Concave {
          Origin { offset[0] * h + offset[1] * k + offset[2] * l }
          Origin { 1.5 * h + 1.5 * l }
          
          // Create a groove for the rod.
          Concave {
            Plane { h }
            Plane { l }
            Origin { 4 * h + 4.25 * l }
            Plane { -h }
            Plane { -l }
          }
          
          // Fill in some places where the bonding topology is ambiguous.
          fillInCorner(majorAxis: h, minorAxis: l)
        }
      }
      
      func createHoleZ(offset: SIMD3<Float>) {
        Concave {
          Origin { offset[0] * h + offset[1] * k + offset[2] * l }
          Origin { 1.5 * h + 1.5 * k }
          
          // Create a groove for the rod.
          Concave {
            Plane { h }
            Plane { k }
            Origin { 4 * h + 4.25 * k }
            Plane { -h }
            Plane { -k }
          }
          
          // Fill in some places where the bonding topology is ambiguous.
          fillInCorner(majorAxis: h, minorAxis: k)
        }
      }
      
      Volume {
        for layerID in 0..<4 {
          let y = 6 * Float(layerID)
          
          for positionZ in 0..<4 {
            // Only send gather3 to bit 3.
            if positionZ == 0, layerID < 3 {
              continue
            }
            
            // Only send gather2 to bits 2 and 3.
            if positionZ == 1, layerID < 2 {
              continue
            }
            
            // Only send gather1 to bits 1, 2, and 3.
            if positionZ == 2, layerID < 1 {
              continue
            }
            
            let z = 5.75 * Float(positionZ)
            createHoleX(offset: SIMD3(0, y + 2.5, z + 0))
          }
          createHoleX(offset: SIMD3(0, y + 2.5, 24 + 2.5))
          
          for positionX in 0..<2 {
            let x = 5.5 * Float(positionX)
            createHoleZ(offset: SIMD3(x + 0, y + 0, 0))
          }
          for positionX in 0..<5 {
            // Only create a rod at positionX=0 for the carry in.
            if positionX == 0, layerID > 0 {
              continue
            }
            
            // Only send propagate1 to bits 1, 2, and 3.
            if positionX == 2, layerID < 1 {
              continue
            }
            
            // Only send propagate2 to bits 2 and 3.
            if positionX == 3, layerID < 2 {
              continue
            }
            
            let x = 5.5 * Float(positionX)
            createHoleZ(offset: SIMD3(x + 13.5, y + 0, 0))
          }
          createHoleZ(offset: SIMD3(41, y + 0, 0))
        }
        
        for positionZ in 0..<4 {
          let z = 5.75 * Float(positionZ)
          createHoleY(offset: SIMD3(11, 0, z + 2.5))
        }
        for positionX in 1..<5 {
          let x = 5.5 * Float(positionX)
          createHoleY(offset: SIMD3(x + 11, 0, 21.25 + 2.5))
        }
        
        Replace { .empty }
      }
      
      // Clean up the extraneous block of atoms on the front.
      Volume {
        Origin { 34.5 * l }
        Plane { l }
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
