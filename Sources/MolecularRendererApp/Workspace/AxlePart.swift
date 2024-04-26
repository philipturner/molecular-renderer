//
//  AxlePart.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 4/25/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct AxlePart: GenericPart {
  var rigidBody: MM4RigidBody
  
  init() {
    let lattice = Self.createLattice()
    let topology = Self.createTopology(lattice: lattice)
    rigidBody = Self.createRigidBody(topology: topology)
    
    let bulkAtomIDs = Self.extractBulkAtomIDs(topology: topology)
    minimize(bulkAtomIDs: bulkAtomIDs)
  }
  
  static func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 40 * h + 40 * k + 40 * l }
      Material { .elemental(.carbon) }
      
      // Trim away the back side, to prevent overlap with the sheet part.
      Volume {
        Origin { 2 * l }
        Plane { -l }
        Replace { .empty }
      }
      
      // Trim a cylinder pointing toward <110>.
      Volume {
        Origin { 7 * l }
        
        let eigenvector0 = l
        let eigenvector1 = (-h + k) / Float(2).squareRoot()
        let radius: Float = 4
        
        for sectorID in 0..<180 {
          let θ = Float(sectorID) * 2 * (Float.pi / 180)
          let coord0 = radius * Float.cos(θ)
          let coord1 = radius * Float.sin(θ)
          
          Convex {
            Origin { coord0 * eigenvector0 }
            Origin { coord1 * eigenvector1 }
            Plane { coord0 * eigenvector0 + coord1 * eigenvector1 }
          }
        }
        
        Replace { .empty }
      }
      
      // Clean up the faces.
      Volume {
        Convex {
          Origin { 6 * k }
          Plane { -h - k }
        }
        Convex {
          Origin { 40 * h + 34 * k }
          Plane { h + k }
        }
        Replace { .empty }
      }
    }
  }
}
