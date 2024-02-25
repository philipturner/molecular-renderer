//
//  DriveWall.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 2/25/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct DriveWall {
  var topology = Topology()
  var rigidBody: MM4RigidBody?
  
  init() {
    topology.atoms = createLattice().atoms
    alignAtoms()
    addHydrogens()
  }
  
  mutating func createLattice() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 4 * h + 17 * h2k + 14 * l }
      Material { .checkerboard(.silicon, .carbon) }
      
      for xIndex in 0..<2 {
        for yIndex in 0..<2 {
          Volume {
            if xIndex == 0 {
              Origin { 2.5 * l }
            } else {
              Origin { 8 * l }
            }
            if yIndex == 0 {
              Origin { 2.5 * h2k }
            } else {
              Origin { 9.5 * h2k }
            }
            
            Concave {
              Origin { 1.9 * h }
              Plane { h }
              
              Convex {
                Origin { -0.1 * l }
                Plane { l }
              }
              Plane { h2k }
              Convex {
                Origin { 0.25 * h2k }
                Plane { k + h }
              }
              
              // Coupled with the origin for h2k.
              Origin { 3.5 * l }
              if yIndex == 0 {
                Origin { 2.5 * h2k }
              } else {
                Origin { 2.25 * h2k }
              }
              Plane { -l }
              Plane { -k + h }
            }
            
            Replace { .empty }
          }
        }
      }
    }
  }
  
  mutating func alignAtoms() {
    let moissaniteHexagonConstant = Constant(.hexagon) {
      .checkerboard(.silicon, .carbon)
    }
    let moissanitePrismConstant = Constant(.prism) {
      .checkerboard(.silicon, .carbon)
    }
    
    for i in topology.atoms.indices {
      var position = topology.atoms[i].position
      position = SIMD3(position.z, position.y, position.x)
      position.x += -1 * moissanitePrismConstant
      position.y += -3.25 * moissaniteHexagonConstant
      position.z += -6 * moissaniteHexagonConstant
      topology.atoms[i].position = position
    }
  }
  
  mutating func addHydrogens() {
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
