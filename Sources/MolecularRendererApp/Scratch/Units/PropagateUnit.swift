//
//  PropagateUnit.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 3/24/24.
//

import Foundation
import HDL
import MM4
import Numerics

struct PropagateUnit {
  // The propagate signal.
  //
  // Ordered from bit 0 -> bit 3.
  var signal: [Rod] = []
  
  // The propagate signal, transmitted vertically.
  // - keys: The source layer.
  // - values: The associated logic rods.
  var probe: [Int: Rod] = [:]
  
  // The propagate signal, broadcasted to every applicable carry chain.
  // - keys: The source layer (0) and the destination layer (1).
  // - values: The associated logic rods.
  var broadcast: [SIMD2<Int>: Rod] = [:]
  
  // The rods in the unit, gathered into an array.
  var rods: [Rod] {
    signal +
    Array(probe.values) +
    Array(broadcast.values)
  }
  
  init() {
    for layerID in 1...4 {
      let y = 6 * Float(layerID)
      
      // Create 'signal'.
      do {
        let offset = SIMD3(0, y, 30.75)
        let pattern = PropagateUnit.signalPattern()
        let rod = PropagateUnit.createRodX(
          offset: offset, pattern: pattern)
        signal.append(rod)
      }
      
      // Create 'broadcast'.
      for positionX in 0..<layerID {
        var offset: SIMD3<Float>
        var pattern: KnobPattern
        
        if layerID == 4 && positionX == 3 {
          // Stack the final broadcast on the top layer, removing a large
          // block of unnecessary housing.
          let x = 7.5 * Float(positionX)
          offset = SIMD3(x + 11, y + 2.75, 0)
          pattern = { h, h2k, l in
            
          }
        } else {
          let x = 7.5 * Float(positionX)
          offset = SIMD3(x + 16, y - 2.75, 0)
          pattern = PropagateUnit.broadcastPattern()
        }
        let rod = PropagateUnit.createRodZ(
          offset: offset, pattern: pattern)
        
        let key = SIMD2(Int(positionX), Int(layerID))
        broadcast[key] = rod
      }
    }
    
    // Create 'probe'.
    for positionX in 0..<3 {
      let x = 7.5 * Float(positionX)
      let offset = SIMD3(x + 13.5, 0, 28)
      let rod = PropagateUnit.createRodY(offset: offset)
      
      let key = positionX
      probe[key] = rod
    }
  }
}

extension PropagateUnit {
  private static func createRodX(
    offset: SIMD3<Float>,
    pattern: KnobPattern
  ) -> Rod {
    let rodLatticeX = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 77 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        pattern(h, h2k, l)
      }
    }
    
    let atoms = rodLatticeX.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position += SIMD3(0, 0.85, 0.91)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
  
  private static func createRodY(offset: SIMD3<Float>) -> Rod {
    let rodLatticeY = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 46 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
    }
    
    let atoms = rodLatticeY.atoms.map {
      var copy = $0
      var position = copy.position
      let latticeConstant = Constant(.square) { .elemental(.carbon) }
      position = SIMD3(position.z, position.x, position.y)
      position += SIMD3(0.91, 0, 0.85)
      position += offset * latticeConstant
      copy.position = position
      return copy
    }
    return Rod(atoms: atoms)
  }
  
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

extension PropagateUnit {
  private static func signalPattern() -> KnobPattern {
    { h, h2k, l in
      Concave {
        Convex {
          Origin { 2 * h }
          Plane { h }
        }
        Convex {
          Origin { 0.5 * h2k }
          Plane { -h2k }
        }
        Convex {
          Origin { 7 * h }
          Plane { -h }
        }
        Replace { .empty }
      }
      
      Concave {
        Convex {
          Origin { 11 * h }
          Plane { h }
        }
        Convex {
          Origin { 0.5 * h2k }
          Plane { -h2k }
        }
        Convex {
          Origin { 16 * h }
          Plane { -h }
        }
        Replace { .empty }
      }
    }
  }
  
  private static func broadcastPattern() -> KnobPattern {
    { h, h2k, l in
      Concave {
        Convex {
          Origin { 45 * h }
          Plane { h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Replace { .empty }
      }
      
      Concave {
        Convex {
          Origin { 42 * h }
          Plane { h }
        }
        Convex {
          Origin { 0.5 * l }
          Plane { -l }
        }
        Convex {
          Origin { 48 * h }
          Plane { -h }
        }
        Replace { .empty }
      }
      
      // Create a silicon dopant.
      Volume {
        Concave {
          Concave {
            Origin { 42 * h }
            Plane { h }
            Origin { 1 * h }
            Plane { -h }
          }
          Concave {
            Origin { 0.4 * l }
            Plane { l }
            Origin { 0.5 * l }
            Plane { -l }
          }
          Concave {
            Origin { 0.5 * h2k }
            Plane { h2k }
            Origin { 0.5 * h2k }
            Plane { -h2k }
          }
          Replace { .atom(.silicon) }
        }
      }
      
      // Create a silicon dopant.
      Volume {
        Concave {
          Concave {
            Origin { 47 * h }
            Plane { h }
            Origin { 1 * h }
            Plane { -h }
          }
          Concave {
            Origin { 0.4 * l }
            Plane { l }
            Origin { 0.5 * l }
            Plane { -l }
          }
          Concave {
            Origin { 0.5 * h2k }
            Plane { h2k }
            Origin { 0.5 * h2k }
            Plane { -h2k }
          }
          Replace { .atom(.silicon) }
        }
      }
      
      // Create a phosphorus dopant.
      Volume {
        Concave {
          Concave {
            Origin { 47 * h }
            Plane { h }
            Origin { 1.5 * h }
            Plane { -h }
          }
          Concave {
            Origin { 0.75 * l }
            Plane { l }
            Origin { 0.5 * l }
            Plane { -l }
          }
          Concave {
            Origin { 0.0 * h2k }
            Plane { h2k }
            Origin { 0.3 * h2k }
            Plane { -h2k }
          }
          Replace { .atom(.phosphorus) }
        }
      }
      
      // Create a phosphorus dopant.
      Volume {
        Concave {
          Concave {
            Origin { 49 * h }
            Plane { h }
            Origin { 1.5 * h }
            Plane { -h }
          }
          Concave {
            Origin { 1.3 * l }
            Plane { l }
            Origin { 0.3 * l }
            Plane { -l }
          }
          Concave {
            Origin { 1.0 * h2k }
            Plane { h2k }
            Origin { 0.5 * h2k }
            Plane { -h2k }
          }
          Replace { .atom(.phosphorus) }
        }
      }
    }
  }
}
