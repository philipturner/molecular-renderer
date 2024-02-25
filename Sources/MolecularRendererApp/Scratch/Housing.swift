//
//  Housing.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 2/25/24.
//

import Foundation
import HDL
import MM4
import Numerics
import OpenMM

struct Housing {
  var topology = Topology()
  
  init() {
    topology.atoms = createLattice().atoms
    alignAtoms()
    addHydrogens()
  }
  
  mutating func createLattice() -> Lattice<Cubic> {
    Lattice<Cubic> { h, k, l in
      Bounds { 16 * h + 20 * k + 8 * l }
      Material { .elemental(.carbon) }
      
      func createRodVolume(xIndex: Int, yIndex: Int) {
        Origin { 8 * Float(xIndex) * h }
        Origin { 10 * Float(yIndex) * k }
        Origin { 4 * h + 3.5 * k }
        
        var loopDirections: [SIMD3<Float>] = []
        loopDirections.append(h)
        loopDirections.append(k)
        loopDirections.append(-h)
        loopDirections.append(-k)
        
        Concave {
          for i in 0..<4 {
            Convex {
              Origin { 2 * loopDirections[i] }
              if i == 1 {
                Origin { 0.25 * k }
              }
              Plane { -loopDirections[i] }
            }
            Convex {
              let current = loopDirections[i]
              let next = loopDirections[(i + 1) % 4]
              Origin { (current + next) * 1.75 }
              if i == 0 || i == 1 {
                Origin { 0.25 * k }
              }
              Plane { (current + next) * -1 }
            }
          }
        }
      }
      
      Volume {
        for xIndex in 0..<2 {
          for yIndex in 0..<2 {
            Convex {
              createRodVolume(xIndex: xIndex, yIndex: yIndex)
            }
          }
        }
        
        Replace { .empty }
      }
    }
  }
  
  mutating func alignAtoms() {
    
  }
  
  mutating func addHydrogens() {
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
