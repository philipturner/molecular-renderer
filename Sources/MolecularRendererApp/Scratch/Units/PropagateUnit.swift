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
        let pattern = PropagateUnit
          .signalPattern(layerID: layerID)
        let rod = PropagateUnit
          .createRodX(offset: offset, pattern: pattern)
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
            Concave {
              Convex {
                Origin { 46 * h }
                Plane { h }
              }
              Convex {
                Origin { 0.5 * h2k }
                Plane { -h2k }
              }
              Convex {
                Origin { 51 * h }
                Plane { -h }
              }
              Replace { .empty }
            }
          }
        } else {
          let x = 7.5 * Float(positionX)
          offset = SIMD3(x + 16, y - 2.75, 0)
          pattern = PropagateUnit.broadcastPattern()
        }
        let rod = PropagateUnit
          .createRodZ(offset: offset, pattern: pattern)
        
        let key = SIMD2(Int(positionX), Int(layerID))
        broadcast[key] = rod
      }
    }
    
    // Create 'probe'.
    for positionX in 0..<3 {
      let x = 7.5 * Float(positionX)
      let offset = SIMD3(x + 13.5, 0, 28)
      let pattern = PropagateUnit
        .probePattern(positionX: positionX)
      let rod = PropagateUnit
        .createRodY(offset: offset, pattern: pattern)
      
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
  
  private static func createRodY(
    offset: SIMD3<Float>,
    pattern: KnobPattern
  ) -> Rod {
    let rodLatticeY = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      Bounds { 46 * h + 2 * h2k + 2 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        pattern(h, h2k, l)
      }
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
  private static func signalPattern(layerID: Int) -> KnobPattern {
    { h, h2k, l in
      // Connect to operand A.
      Volume {
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
      }
      
      // Connect to operand B.
      Volume {
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
      
      // Create a groove for interaction with 'probe'.
      Volume {
        Concave {
          Convex {
            Origin { 21 * h }
            Plane { h }
          }
          Convex {
            Origin { 0.5 * l }
            Plane { -l }
          }
          Convex {
            var origin: Float
            switch layerID {
            case 1: origin = 27
            case 2: origin = 37
            case 3: origin = 48
            case 4: origin = 52
            default: fatalError("Unexpected layer ID.")
            }
            Origin { origin * h }
            Plane { -h }
          }
          Replace { .empty }
        }
      }
      createLowerSiliconDopant(offsetH: 21)
      do {
        var origin: Float
        switch layerID {
        case 1: origin = 26
        case 2: origin = 36
        case 3: origin = 47
        case 4: origin = 51
        default: fatalError("Unexpected layer ID.")
        }
        createLowerSiliconDopant(offsetH: origin)
      }
      
      // Create a groove to avoid interaction with 'probe' on other layers.
      if layerID <= 2 {
        Volume {
          Concave {
            Convex {
              var origin: Float
              switch layerID {
              case 1: origin = 31.5
              case 2: origin = 42.5
              default: fatalError("Unexpected layer ID.")
              }
              Origin { origin * h }
              Plane { h }
            }
            Convex {
              Origin { 0.5 * l }
              Plane { -l }
            }
            Convex {
              Origin { 51.5 * h }
              Plane { -h }
            }
            Replace { .empty }
          }
        }
        do {
          var origin: Float
          switch layerID {
          case 1: origin = 31.5
          case 2: origin = 42.5
          default: fatalError("Unexpected layer ID.")
          }
          createUpperSiliconDopant(offsetH: origin)
        }
        createUpperSiliconDopant(offsetH: 50.5)
      }
      
      // Create a groove to directly transmit signals to 'broadcast'.
      //
      // This might warrant some extra P dopants to balance out the twist.
      if layerID == 4 {
        Volume {
          Concave {
            Convex {
              Origin { 50 * h }
              Plane { h }
            }
            Convex {
              Origin { 1.5 * h2k }
              Plane { h2k }
            }
            Convex {
              Origin { 55 * h }
              Plane { -h }
            }
            Replace { .empty }
          }
        }
      }
      
      func createLowerSiliconDopant(offsetH: Float) {
        Volume {
          Concave {
            Concave {
              Origin { offsetH * h }
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
      }
      
      func createUpperSiliconDopant(offsetH: Float) {
        Volume {
          Concave {
            Concave {
              Origin { offsetH * h }
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
              Origin { 1 * h2k }
              Plane { h2k }
              Origin { 0.5 * h2k }
              Plane { -h2k }
            }
            Replace { .atom(.silicon) }
          }
        }
      }
    }
  }
  
  private static func probePattern(positionX: Int) -> KnobPattern {
    { h, h2k, l in
      // Create a groove to receive signals from 'signal'.
      Concave {
        Convex {
          var origin: Float
          switch positionX {
          case 0: origin = 11
          case 1: origin = 19
          case 2: origin = 28
          default: fatalError("Unrecognized position X.")
          }
          Origin { origin * h }
          Plane { h }
        }
        Convex {
          Origin { 1.5 * h2k }
          Plane { h2k }
        }
        Convex {
          var origin: Float
          switch positionX {
          case 0: origin = 16
          case 1: origin = 25
          case 2: origin = 33
          default: fatalError("Unrecognized position X.")
          }
          Origin { origin * h }
          Plane { -h }
        }
        Replace { .empty }
      }
      
      // Create a groove to transmit signals to 'broadcast' on layer 1.
      if positionX <= 0 {
        Concave {
          Convex {
            // -4 units from the mobile position.
            Origin { 2.5 * h }
            Plane { h }
          }
          Convex {
            Origin { 1.49 * l }
            Plane { l }
          }
          Convex {
            // -4 units from the mobile position.
            Origin { 8.5 * h }
            Plane { -h }
          }
          Replace { .empty }
        }
        createUpperSiliconDopant(offsetH: 2.5)
        createUpperSiliconDopant(offsetH: 7.5)
      }
      
      // Create a groove to transmit signals to 'broadcast' on layer 2.
      if positionX <= 1 {
        Concave {
          Convex {
            // -4 units from the mobile position.
            Origin { 11 * h }
            Plane { h }
          }
          Convex {
            Origin { 1.49 * l }
            Plane { l }
          }
          Convex {
            // -4 units from the mobile position.
            Origin { 17 * h }
            Plane { -h }
          }
          Replace { .empty }
        }
        createLowerSiliconDopant(offsetH: 11)
        createLowerSiliconDopant(offsetH: 16)
      }
      
      // Create a groove to transmit signals to 'broadcast' on layer 3.
      Concave {
        Convex {
          // -4 units from the mobile position.
          Origin { 19.5 * h }
          Plane { h }
        }
        Convex {
          Origin { 1.49 * l }
          Plane { l }
        }
        Convex {
          // -4 units from the mobile position.
          Origin { 25.5 * h }
          Plane { -h }
        }
        Replace { .empty }
      }
      if positionX == 1 {
        createUpperPhosphorusDopant(offsetH: 19.5)
      } else {
        createUpperSiliconDopant(offsetH: 19.5)
      }
      createUpperSiliconDopant(offsetH: 24.5)
      
      // Create a groove to transmit signals to 'broadcast' on layer 4.
      Concave {
        Convex {
          // -4 units from the mobile position.
          Origin { 28 * h }
          Plane { h }
        }
        Convex {
          Origin { 1.49 * l }
          Plane { l }
        }
        Convex {
          // -4 units from the mobile position.
          Origin { 34 * h }
          Plane { -h }
        }
        Replace { .empty }
      }
      createLowerSiliconDopant(offsetH: 28)
      createLowerSiliconDopant(offsetH: 33)
      
      func createLowerSiliconDopant(offsetH: Float) {
        Volume {
          Concave {
            Concave {
              Origin { offsetH * h }
              Plane { h }
              Origin { 1 * h }
              Plane { -h }
            }
            Concave {
              Origin { 0.9 * l }
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
      }
      
      func createUpperSiliconDopant(offsetH: Float) {
        Volume {
          Concave {
            Concave {
              Origin { offsetH * h }
              Plane { h }
              Origin { 1 * h }
              Plane { -h }
            }
            Concave {
              Origin { 0.9 * l }
              Plane { l }
              Origin { 0.5 * l }
              Plane { -l }
            }
            Concave {
              Origin { 1 * h2k }
              Plane { h2k }
              Origin { 0.5 * h2k }
              Plane { -h2k }
            }
            Replace { .atom(.silicon) }
          }
        }
      }
      
      func createUpperPhosphorusDopant(offsetH: Float) {
        Volume {
          Concave {
            Concave {
              Origin { offsetH * h }
              Plane { h }
              Origin { 1 * h }
              Plane { -h }
            }
            Concave {
              Origin { 0.9 * l }
              Plane { l }
              Origin { 0.5 * l }
              Plane { -l }
            }
            Concave {
              Origin { 1 * h2k }
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
  
  private static func broadcastPattern() -> KnobPattern {
    { h, h2k, l in
      // Create a groove to avoid interaction with 'signal'.
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
      
      // Create a groove to receive signals from 'probe'.
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
      createSiliconDopant(offsetH: 42)
      createSiliconDopant(offsetH: 47)
      createFirstPhosphorusDopant()
      createSecondPhosphorusDopant()
      
      func createSiliconDopant(offsetH: Float) {
        Volume {
          Concave {
            Concave {
              Origin { offsetH * h }
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
      }
      
      func createFirstPhosphorusDopant() {
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
      }
      
      func createSecondPhosphorusDopant() {
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
}
