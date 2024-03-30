//
//  InputUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct InputUnit {
  // The A input to the circuit.
  //
  // Ordered from bit 0 -> bit 3.
  var operandA: [Rod] = []
  
  // The B input to the circuit.
  //
  // Ordered from bit 0 -> bit 3.
  var operandB: [Rod] = []
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    operandA +
    operandB
  }
  
  init() {
    for layerID in 1...4 {
      let y = 6 * Float(layerID)
      
      // Create 'operandA'.
      do {
        let offset = SIMD3(0, y - 2.75, 0)
        let pattern = InputUnit
          .commonPattern(layerID: layerID)
        let rod = InputUnit
          .createRodZ(offset: offset, pattern: pattern)
        operandA.append(rod)
      }
      
      // Create 'operandB'.
      do {
        let offset = SIMD3(5.75, y - 2.75, 0)
        let pattern = InputUnit
          .commonPattern(layerID: layerID)
        let rod = InputUnit
          .createRodZ(offset: offset, pattern: pattern)
        operandB.append(rod)
      }
    }
  }
}

extension InputUnit {
  private static func createRodZ(
    offset: SIMD3<Float>,
    pattern: KnobPattern
  ) -> Rod {
    let rodLatticeZ = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 54 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        pattern(h, h2k, l)
      }
    }
    
    let atoms = rodLatticeZ.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position = SIMD3(position.z, position.y, position.x)
      position += SIMD3(0.91, 0.85, 0)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
}

extension InputUnit {
  // A pattern common to both operands.
  private static func commonPattern(layerID: Int) -> KnobPattern {
    { h, h2k, l in
      Concave {
        Convex {
          Origin { 46 * h }
          Plane { h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Convex {
          Origin { 51 * h }
          Plane { -h }
        }
        Replace { .empty }
      }
      
      Concave {
        Convex {
          // +4 units from the mobile position.
          var origin: Float
          switch layerID {
          case 1: origin = 31
          case 2: origin = 22
          case 3: origin = 14
          case 4: origin = 6
          default: fatalError("Unexpected layer ID.")
          }
          Origin { origin * h }
          Plane { h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Convex {
          // +4 units from the mobile position.
          var origin: Float
          switch layerID {
          case 1: origin = 36
          case 2: origin = 28
          case 3: origin = 20
          case 4: origin = 12
          default: fatalError("Unexpected layer ID.")
          }
          Origin { origin * h }
          Plane { -h }
        }
        Replace { .empty }
      }
    }
  }
}
