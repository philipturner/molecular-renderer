//
//  Chapter12_Figure1_file2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/30/23.
//

import Foundation
import HDL
import MolecularRenderer
import simd

extension Nanosystems.Chapter12.Figure1 {
  func secondRod() -> Lattice<Hexagonal> {
    Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 32 * h + 8 * h2k + 6 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        // Trim some atoms off each end.
        Convex {
          Origin { 1.3 * h }
          Plane { -h }
        }
        Convex {
          Origin { 30.8 * h }
          Plane { h }
          Replace { .empty }
        }
        Origin { 16 * h + 4 * h2k + 3 * l }
        
        for direction in [-l, l] {
          Convex {
            if direction.z > 0 {
              Origin { 2.3 * direction }
            } else {
              Origin { 0.2 * direction }
            }
            Plane { direction }
          }
        }
        Convex {
          Origin { 3.5 * h2k }
          Plane { h2k }
        }
        
        // Cut the rod so only the probe knob remains.
        for direction in [h, -h] {
          Volume {
            Concave {
              Origin { 0.5 * h2k }
              Plane { h2k }
              
              // Set direction to negative for now, so it cuts out the knob.
              if direction.x > 0 {
                Origin { 0.5 * -direction }
              } else {
                Origin { 3.5 * -direction }
              }
              Plane { direction }
            }
            Replace { .empty }
          }
        }
        
        Convex {
          Origin { -1.5 * h2k }
          Plane { -h2k }
        }
        
        Replace { .empty }
      }
    }
  }
  
  func secondHole(_ h: SIMD3<Float>, _ k: SIMD3<Float>, _ l: SIMD3<Float>) {
    Volume {
      let h2k = h + 2 * k
      Origin { 10 * h + 5 * h2k + 3 * l }
      
      Concave {
        for direction in [-l, l] {
          Convex {
            if direction.z > 0 {
              Origin { 2.8 * direction }
            } else {
              Origin { 1.2 * direction }
            }
            Plane { -direction }
          }
        }
        Convex {
          Origin { -2.5 * h2k }
          Plane { h2k }
          
          // Remove some atoms that are an intense source of energy dissipation.
          for direction in [k + h, k] {
            Convex {
              Origin { 4 * direction }
              Plane { direction }
            }
          }
        }
        Convex {
          Origin { h2k }
          Plane { -h2k }
        }
      }
      Replace { .empty }
    }
  }
}
