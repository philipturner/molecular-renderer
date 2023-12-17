//
//  Scratch2.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/16/23.
//

import Foundation
import HDL
import MolecularRenderer
import Numerics

// MARK: - Crystolecules

func createRobotClawLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 30 * h + 85 * h2k + 4 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 15 * h + 10 * h2k + 2 * l }
      
      Concave {
        for direction in [h, -h, k, h + k] {
          Convex {
            Origin { 9 * direction }
            Plane { -direction }
          }
        }
      }
      Concave {
        Convex {
          for direction in [h, -h] {
            Convex {
              Origin { 6 * direction }
              Plane { direction }
            }
          }
        }
        Convex {
          for direction in [h, -h, k, h + k] {
            Convex {
              Origin { 14 * direction }
              Plane { direction }
            }
          }
          for direction in [-k, -h - k] {
            Convex {
              Origin { -2 * h2k }
              Origin { 14 * direction }
              Plane { direction }
            }
          }
        }
      }
      
      for hSign in [Float(1), -1] {
        Concave {
          Origin { 34 * h2k }
          Convex {
            Origin { 6 * hSign * h }
            Plane { hSign * h + h2k }
          }
          Convex {
            Origin { 4 * hSign * h }
            Plane { hSign * h }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createHexagonLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 24 * h + 24 * h2k + 3 * l }
    Material { .checkerboard(.carbon, .germanium) }
    
    Volume {
      Convex {
        Origin { 0.7 * l }
        Plane { l }
      }
      
      Origin { 12 * h + 12 * h2k }
      
      let directions1 = [h, h + k, k, -h, -k - h, -k]
      var directions2: [SIMD3<Float>] = []
      directions2.append(h * 2 + k)
      directions2.append(h + 2 * k)
      directions2.append(k - h)
      directions2 += directions2.map(-)
      
      for direction in directions1 {
        Convex {
          Origin { 6 * 1.5 * direction }
          Plane { direction }
        }
      }
      for direction in directions2 {
        Convex {
          Origin { (6 - 0.5) * direction }
          Plane { direction }
        }
      }
      Concave {
        for direction in directions1 {
          Convex {
            Origin { 4 * 1.5 * direction }
            Plane { -direction }
          }
        }
        for direction in directions2 {
          Convex {
            Origin { (4 - 0.5) * direction }
            Plane { -direction }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createBandLattice() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + 9 * h2k + 60 * l }
    Material { .checkerboard(.carbon, .silicon) }
    
    Volume {
      Origin { 5 * h + 3.5 * h2k + 0 * l }
      
      Concave {
        Origin { -0.25 * h2k }
        for direction in [4 * h, 1.75 * h2k, -4 * h, -2.25 * h2k] {
          Convex {
            Origin { 1 * direction }
            Plane { -direction }
          }
        }
      }
      
      for directionPair in [(h, 2 * h + k), (-h, k - h)] {
        Concave {
          Convex {
            Origin { 2 * directionPair.0 }
            Plane { directionPair.0 }
          }
          Convex {
            Origin { 3.75 * directionPair.1 }
            Plane { directionPair.1 }
          }
        }
      }
      
      Concave {
        Origin { 2.8 * l }
        Plane { l }
        Origin { 2.5 * h2k }
        Plane { -h2k }
      }
      
      for direction in [h, -h] {
        Concave {
          Origin { 2.8 * l }
          Plane { l }
          Origin { 2 * direction }
          Plane { direction }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createRoofPieceLattice(xCenter: Float) -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let holeSpacing: Float = 8
    let holeWidth: Float = 5
    
    let xWidth: Float = 22
    let yHeight: Float = 4
    let zWidth: Float = (3*2) * holeSpacing
    let h2k = h + 2 * k
    Bounds { xWidth * h + yHeight * h2k + zWidth * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Convex {
        Origin { 1 * h }
        Plane { -h }
      }
      Convex {
        Origin { xWidth * h }
        Concave {
          Origin { yHeight/2 * h2k }
          Origin { -4 * h }
          Plane { -k + h }
          Plane { h + k + h }
        }
        
        Origin { -6 * h }
        Concave {
          Origin { 1 * h2k }
          Plane { -h2k }
          Plane { -h - k }
        }
        Concave {
          Origin { (yHeight - 1) * h2k }
          Plane { h2k }
          Plane { k }
        }
      }
      Origin { xCenter * h + yHeight/2 * h2k + 0 * l }
      
      for hDirection in [h, -h] {
        for lIndex in 0...Int(zWidth / holeSpacing + 1e-3) {
          Concave {
            Origin { (hDirection.x > 0) ? 3 * h : -2 * h }
            Plane { hDirection }
            
            Origin { holeSpacing * Float(lIndex) * l }
            Convex {
              Origin { -holeWidth/2 * l }
              Origin { -0.25 * l }
              Plane { l }
            }
            Convex {
              Origin { holeWidth/2 * l }
              Plane { -l }
            }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createControlRod(length: Int) -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 10 * h + Float(length) * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      // Add a hook-like feature to the end of the control rod.
      Convex {
        Origin { 6 * h }
        Plane { h - k }
      }
      Concave {
        Origin { 8 * h + 5 * h2k }
        Plane { -h }
        Plane { k - h }
      }
      
      Replace { .empty }
    }
  }
}

// The assembly housing DSL code is ~150-200 lines - one of the
// most unwieldy pieces in this project. Refrain from pieces like
// this as much as possible; designing the geometry for them
// consumes an exorbitant amount of time.
//
// Cubic lattices creating cartesian geometry are very time-consuming. But
// sometimes, the end result is worth the effort. Here, the piece ended up
// tiling to interlock with nearby quadrants. That was not anticipated when
// first designing it.
func createAssemblyHousing(terminal: Bool) -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    let spanX: Float = 35
    let spanY: Float = 77
    let spanZ: Float = 67
    let beamPositionX: Float = 7
    let beamPositionY: Float = 45
    Bounds {
      (4 + spanX) * h +
      (4 + spanY) * k +
      (4 + spanZ) * l }
    Material { .elemental(.germanium) }
    
    func _createBeam(
      principalAxis1: SIMD3<Float>,
      principalAxis2: SIMD3<Float>
    ) {
      for negate1 in [false, true] {
        for negate2 in [false, true] {
          var direction: SIMD3<Float> = .zero
          direction += negate1 ? -principalAxis1 : principalAxis1
          direction += negate2 ? -principalAxis2 : principalAxis2
          Convex {
            Origin { 1.5 * direction }
            Plane { direction }
          }
        }
      }
    }
    
    func createBeamX() {
      Convex {
        Convex {
          Origin { 1 * h }
          Ridge(-h + k) { -h }
        }
        Convex {
          Origin { beamPositionX * h }
          _createBeam(
            principalAxis1: k, principalAxis2: l)
        }
        Convex {
          Origin { (spanX - 4) * h }
          Plane { h }
        }
        if terminal {
          Convex {
            Origin { (beamPositionX + 3) * h }
            Convex {
              Ridge(h + k) { h }
              Ridge(h + l) { h }
            }
          }
        }
      }
      if !terminal { createConnectorX() }
    }
    
    func createBeamY() {
      Convex {
        Origin { beamPositionX * h }
        Convex {
          Origin { -3 * k }
          Ridge(-k + h) { -k }
          Ridge(-k + l) { -k }
        }
        _createBeam(principalAxis1: h, principalAxis2: l)
        
        Origin { (spanY - 3) * k }
        Convex {
          Ridge(k + h) { k }
          Ridge(k + l) { k }
        }
      }
    }
    
    func createBeamZ() {
      Convex {
        Origin { beamPositionX * h }
        Convex {
          Origin { -3 * l }
          Ridge(-l + h) { -l }
          Ridge(-l + k) { -l }
        }
        _createBeam(principalAxis1: h, principalAxis2: k)
        
        Origin { (spanZ - 3) * l }
        Convex {
          Ridge(l + h) { l }
          Ridge(l + k) { l }
        }
      }
    }
    
    // Slight bulge to prepare for connecting with the next piece.
    func createConnectorX() {
      Convex {
        Convex {
          Origin { (spanX - 8.25) * h }
          Ridge(-h + l + k) { -h }
        }
        Convex {
          Origin { (spanX - 8) * h }
          Ridge(-h + l - k) { -h }
        }
        for direction in [l+k, l-k, -l+k, -l-k] {
          Convex {
            Origin { 2 * direction }
            Plane { direction }
          }
        }
        for lNegative in [true, false] {
          Convex {
            Origin { (lNegative ? -1.5 : 1.5) * l }
            let lDir = lNegative ? -l : l
            Valley(lDir + k) { lDir }
          }
        }
        Convex {
          Origin { (spanX - 3.5) * h }
          Valley(h + k) { h }
        }
        
        // Remove some methyl carbons.
        Convex {
          Origin { (spanX + 4.5) * h }
          Ridge(h + k) { h }
        }
      }
    }
    
    Volume {
      Origin { 2 * (h + k + l) }
      
      Concave {
        Concave {
          Origin { 3 * k }
          Origin { 3 * l }
          createBeamX()
          createBeamY()
          createBeamZ()
        }
        
        Concave {
          Origin { 3 * k }
          Origin { (spanZ - 3) * l }
          createBeamX()
          createBeamY()
        }
        
        for positionY in [beamPositionY, spanY - 3] {
          Concave {
            Origin { positionY * k }
            Origin { 3 * l }
            createBeamX()
            createBeamZ()
          }
          
          Concave {
            Origin { positionY * k }
            Origin { (spanZ - 3) * l }
            createBeamX()
          }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createNewBackBoardLattice1() -> Lattice<Hexagonal> {
  var archSpacing: Float = 18.2
  archSpacing /= Constant(.hexagon) { .elemental(.carbon) }
  archSpacing.round(.toNearestOrEven)
  
  return Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 120 * h + 100 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Origin { 9 * h }
      Origin { archSpacing/2 * h }
      
      Concave {
        Convex {
          Origin { -15 * h }
          Plane { h }
        }
        Convex {
          Origin { 15 * h }
          Plane { -h }
        }
        Origin { 35 * h2k }
        for direction in [k, h + k] {
          Convex {
            Origin { 12 * direction }
            Plane { -direction }
          }
        }
      }
      
      Convex {
        Origin { -0.75 * h }
        Plane { h }
      }
      Convex {
        Origin { (-archSpacing/2 + 0.5) * h }
        Plane { -h }
      }
      
      Replace { .empty }
    }
  }
}

func createNewBackBoardLattice2() -> Lattice<Hexagonal> {
  var archSpacing: Float = 18.2
  archSpacing /= Constant(.hexagon) { .elemental(.carbon) }
  archSpacing.round(.toNearestOrEven)
  
  return Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 357 * h + 100 * h2k + 1 * l }
    Material { .elemental(.carbon) }
    
    func createArch(index: Int) {
      Origin { 9 * h }
      Origin { Float(index) * archSpacing * h }
      Origin { archSpacing/2 * h }
      
      Concave {
        Convex {
          Origin { -15 * h }
          Plane { h }
        }
        Convex {
          Origin { 15 * h }
          Plane { -h }
        }
        Origin { 35 * h2k }
        for direction in [k, h + k] {
          Convex {
            Origin { 12 * direction }
            Plane { -direction }
          }
        }
      }
      
      Convex {
        Origin { 0.75 * h }
        Plane { -h }
      }
    }
    
    Volume {
      Convex {
        createArch(index: 4)
      }
      
      for elevation in [Float(5), 59, 96] {
        Convex {
          Origin { 352 * h }
          Origin { elevation * h2k }
          Concave {
            Plane { h + k + h }
            Plane { -k + h }
          }
        }
      }
      
      Replace { .empty }
    }
  }
}
