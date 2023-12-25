//
//  ConvergentAssemblyArchitecture2.swift
//  HardwareCatalog
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
        }
      }
      Concave {
        Convex {
          Origin { 1 * h2k }
          Origin { 14 * (-k) }
          Plane { -k - h }
        }
        Convex {
          Origin { 1 * h2k }
          Origin { 14 * (-k - h) }
          Plane { -k }
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

func createFloorHexagon(
  radius: Float,
  thickness: Int
) -> Lattice<Hexagonal> {
  var hexagonRadius = radius
  hexagonRadius /= Constant(.hexagon) { .checkerboard(.silicon, .carbon) }
  hexagonRadius.round(.toNearestOrEven)
  
  return Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { (2*hexagonRadius) * h + (2*hexagonRadius) * h2k + 3 * l }
    Material { .checkerboard(.silicon, .carbon) }
    
    Volume {
      Origin { hexagonRadius * h + hexagonRadius * h2k }
      
      var directions: [SIMD3<Float>] = []
      directions.append(h)
      directions.append(k + h)
      directions.append(k)
      directions.append(-h)
      directions.append(-k - h)
      directions.append(-k)
      
      Concave {
        for direction in directions {
          Convex {
            Origin { (hexagonRadius - Float(thickness)) * direction }
            Plane { -direction }
          }
        }
      }
      
      for direction in directions {
        Convex {
          Origin { hexagonRadius * direction }
          Plane { direction }
        }
      }
      
      Replace { .empty }
    }
  }
}

func createBroadcastRod() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 284 * h + 10 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    func createCutPair() {
      Concave {
        Convex {
          Origin { 3 * h }
          Plane { -k }
        }
        Convex {
          Origin { 3 * h2k }
          Plane { -h2k }
        }
        Convex {
          Origin { 69 * h }
          Plane { -k - h }
        }
      }
      
      Concave {
        Origin { 5 * h2k }
        Convex {
          Origin { -12 * h }
          Plane { k + h }
        }
        Convex {
          Origin { -3 * h2k }
          Plane { h2k }
        }
        Convex {
          Origin { 12 * h }
          Plane { k }
        }
      }
    }
    
    Volume {
      Convex {
        Origin { 5 * h2k }
        Plane { h2k }
      }
      Convex {
        Origin { 40 * h }
        Plane { -h }
      }
      
      for index in 0..<5 {
        Convex {
          Origin { -20 * h }
          Origin { Float(index) * 72 * h }
          createCutPair()
        }
      }
      
      Replace { .empty }
    }
  }
}

func createBeltLink() -> Lattice<Hexagonal> {
  // One encounter mechanism is 4 nm x 4 nm x 2 nm in Nanosystems 13.3.5(a).
  // 16 = 4 / Constant(.hexagon) { .elemental(.carbon) }
  //  5 = 2 / Float(3).squareRoot() / Constant(.hexagon) { .elemental(.carbon) }
  // 10 = 4 / Constant(.prism) { .elemental(.carbon) }
  
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 5 * h2k + 14 * l }
    Material { .elemental(.carbon) }
    
    func createEncounterVolume() {
      Convex {
        Plane { -h }
        Plane { -h2k }
        Plane { -l }
        Origin  { 11.5 * h + 5 * h2k + 7.00 * l }
        Plane { h }
        Plane { h2k }
        Plane { l }
      }
    }
    
    func createKnob() {
      Convex {
        Origin { 2 * h2k }
        Plane { h2k }
      }
      Convex {
        Origin { 1 * h2k }
        Plane { k - h }
      }
      Convex {
        Origin { 1 * h2k }
        Plane { -k - h - h }
      }
      Convex {
        Origin { 4 * h }
        Plane { h }
      }
      Origin { -0.125 * l }
      Concave {
        for direction in [l, -l] {
          Convex {
            Origin { 3 * direction }
            Plane { -direction }
          }
        }
      }
    }
    
    func createHook() {
      let leftPosition: Float = -8
      Convex {
        Origin { (leftPosition + 0.75) * h }
        Plane { -h }
      }
      Convex {
        Origin { 8 * h }
        Plane { h }
        Origin { 4.75 * h2k }
        Plane { -(k - h) }
      }
      Concave {
        Origin { (leftPosition + 3.5) * h + 3 * h2k }
        Plane { h }
        Plane { -h2k }
        Convex {
          Origin { 0.75 * -(k - h) }
          Plane { -(k - h) }
        }
      }
      Convex {
        Origin { (leftPosition + 0.5) * h + 5 * h2k }
        Plane { -h }
        Plane { h2k }
        Convex {
          Origin { 1.25 * -(k - h) }
          Plane { (k - h) }
        }
        Convex {
          Origin { 2 * -k }
          Plane { k }
        }
      }
      Origin { -0.125 * l }
      Concave {
        Convex {
          Origin { 4.5 * h }
          Plane { -h }
        }
        for direction in [l, -l] {
          Convex {
            Origin { 4.5 * direction }
            Plane { -direction }
          }
        }
      }
    }
    
    // Hook and knob-style connectors. The hook protrudes from the current
    // object and latches onto the opposite side of the adjacent object. There
    // should be enough breathing room for the belt to be inclined at a slight
    // angle.
    Volume {
      Origin { 8 * h + 1 * l }
      Concave {
        Convex {
          Origin { 4.5 * h + 2.25 * l }
          createEncounterVolume()
        }
        Convex {
          Origin { 12 * h }
          Origin { 6 * l }
          createKnob()
        }
        Convex {
          Origin { 6 * l }
          createHook()
        }
      }
      for direction in [l, -l] {
        Convex {
          Origin { -0.125 * l }
          Origin { 6 * l + 6 * direction }
          Plane { direction }
        }
      }
      Replace { .empty }
    }
  }
}

// The part that should have a rubber gripper attached.
func createServoArmPart1() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 17 * h + 40 * h2k + 2 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Convex {
        Origin { 2 * h2k }
        Plane { -k }
      }
      Concave {
        Origin { 4 * h }
        Plane { h }
        Origin { 6 * h2k }
        Plane { -k }
      }
      Concave {
        Origin { 4 * h }
        Plane { h }
        Origin { 8 * h2k }
        Plane { k }
        Origin { 8 * h2k }
        Plane { -k - h }
        Origin { 9 * h }
        Plane { -h }
      }
      Concave {
        Origin { 13 * h }
        Plane { -h }
        Origin { 15 * h2k }
        Plane { k + h }
        Origin { 8 * h2k }
        Plane { -k }
        Origin { -9 * h }
        Plane { h }
      }
      Concave {
        Origin { 21 * h2k }
        Plane { k }
      }
      Concave {
        Origin { 17 * h }
        Origin { 24 * h2k }
        Plane { k + h }
      }
      
      Replace { .empty }
    }
  }
}

// This is the rubber gripper made of diamond.
func createServoArmGripper() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 25 * h + 35 * h2k + 12 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Concave {
        Origin { 8 * h + 14 * h2k }
        Plane { k }
        Plane { -h }
      }
      Concave {
        Convex {
          Origin { 16 * h + 5 * h2k }
          Plane { h }
          Plane { -k }
        }
        Convex {
          Origin { 16 * h + 16 * h2k }
          Plane { -k }
        }
      }
      Convex {
        Origin { 30 * h + 25.5 * h2k }
        Plane { k }
      }
      Concave {
        Origin { 6 * h + 8 * h2k }
        Plane { h }
        Plane { -k }
      }
      Concave {
        Origin { 4 * h + 9 * l }
        Plane { h }
        Plane { -l }
      }
      
      Replace { .empty }
    }
  }
}

// This connects part 1 to the housing.
func createServoArmConnector() -> Lattice<Hexagonal> {
  Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { 54 * h + 30 * h2k + 2 * l }
    Material { .elemental(.carbon) }
    
    Volume {
      Convex {
        Origin { 50 * h }
        Plane { -k - h }
      }
      Convex {
        Origin { 50 * h + 4 * h2k }
        Plane { k + h }
      }
      Convex {
        Origin { 17 * h + 13 * h2k }
        Plane { -h }
        Plane { k }
      }
      Replace { .empty }
    }
  }
}

func createMethyleneTripod() -> [MRAtom] {
  let sp2OptimizedStructureC: String = """
  $coord
         -5.43855232852870        8.99458045508912        0.37626825780162      c
         -6.27943854239138        9.42212815669154        2.21199838877255      h
         -5.52300000000000        5.62700000000000        0.03100000000000      s
         -6.66878375912714        9.75125127868479       -1.09807933252161      h
          2.39333118561696        9.00080106543390       -4.89399976308302      c
          4.28563580688003        9.75668673670454       -5.22203008438962      h
          1.22490473636184        9.43160478422185       -6.53981882725998      h
          2.73500000000000        5.62700000000000       -4.79900000000000      s
         -1.52638587025385        9.43528901268122       -2.26843571490769      c
         -2.60487074721975       10.16771631758159       -3.87327489470373      h
         -1.58999628609673        7.36900476775243       -2.35744462300551      h
          1.56935954181602       10.25774858026075        2.33096500538242      c
         -1.20670073046673        9.43985063549735        2.45916754482047      c
         -2.04978207804903       10.17701622172780        4.19722119811658      h
         -1.25547309266125        7.37379129079133        2.56219358495465      h
         -2.80776419587393       10.26327986639584        0.19367015679663      c
          2.72559617705612        9.41134700708302       -0.18166805389587      c
          2.80871211846553        7.34414200003378       -0.18740547245527      h
          4.66360556361420       10.11884618502805       -0.31904214647371      h
          1.23761892642934       10.25577652133946       -2.51727766812973      c
          1.46501748980601       13.09608137306827       -2.97020600207515      c
          0.46075888970097       13.62284473394430       -4.69016053719710      h
          3.43879242474969       13.63039809996649       -3.21760582623245      h
         -3.32729477264659       13.10787502278530        0.23795534902908      c
         -4.32164052831281       13.60556932846594        1.97359565043939      h
         -4.55836710034056       13.62115800812884       -1.33329540355433      h
         -0.03294268092000       14.84903675121067        0.00779809955409      ge
         -0.02318694111908       18.43861953748099        0.00831080725576      c
          3.03694876037604        9.00078463986672        4.52720373925894      c
          5.04739688607491        9.43165754689817        4.34697649303471      h
          2.78800000000000        5.62699999999999        4.76800000000000      s
          2.36683751733272        9.75519530624151        6.32753654829293      h
          1.87809869699570       13.09856586813082        2.73438696112623      c
          3.87289011058419       13.61117350281227        2.68917136072330      h
          1.14308033575415       13.64130735528931        4.58074532814815      h
          1.70205714323292       19.50706969518398       -0.02237034685116      h
         -1.73798022840540       19.52236007716310        0.03597250249855      h
  $eht charge=0 unpaired=4
  $end
  """
  
  let postOptimization = importFromXTB(sp2OptimizedStructureC)
  return postOptimization
}

func createHAbstTripod() -> [MRAtom] {
  let string = """
  $coord
         -5.44727694650462        8.99232130011734        0.37688933229557      c
         -6.28473421350535        9.42111536356280        2.21338658370895      h
         -5.52300000000000        5.62700000000000        0.03100000000000      s
         -6.67725880819754        9.75087641644443       -1.09606350899717      h
          2.39596415904597        8.99266521278409       -4.90086661155050      c
          4.28634048493446        9.75208143801465       -5.22887407139455      h
          1.22394758146730        9.42307380034253       -6.54374524378439      h
          2.73500000000000        5.62700000000000       -4.79900000000000      s
         -1.52834975027937        9.43998768360104       -2.27166649945318      c
         -2.60957872255028       10.17459992661294       -3.87388570710720      h
         -1.59173552466351        7.37445141454970       -2.36436417043208      h
          1.56758370426345       10.26181589656369        2.33886407070246      c
         -1.20944829560980        9.44166630605072        2.46174279541560      c
         -2.05603465466598       10.17834515495389        4.19855001202845      h
         -1.25923268976048        7.37624293493604        2.56478523892335      h
         -2.81099013608837       10.26271967125220        0.19369973950991      c
          2.72741721212398        9.43367288704683       -0.18133549837998      c
          2.82912840229122        7.36751701514736       -0.18843550546130      h
          4.65925752150450       10.15832853228968       -0.31699991476762      h
          1.23659412527296       10.26091102035311       -2.52487914706549      c
          1.46539460807326       13.10208285292898       -3.00777771442032      c
          0.45636757524017       13.61733035166964       -4.72922921745425      h
          3.43968442028774       13.63094595749751       -3.27123006623057      h
         -3.34315990099951       13.10303012551060        0.23979188717593      c
         -4.32406563919130       13.61807129085861        1.97734692917770      h
         -4.56143453374739       13.63440579181580       -1.33469814747344      h
         -0.00183516504007       14.77248598710659        0.00206453184968      ge
         -0.01035753811694       18.40752311816935        0.00462583992434      c
          3.04226255297146        8.99323884893893        4.53265665174611      c
          5.05087452342753        9.42688450404687        4.34494450495827      h
          2.78800000000000        5.62699999999999        4.76800000000000      s
          2.37529001598303        9.74876501885048        6.33329310892159      h
          1.87826621982991       13.10285760479338        2.77334338667089      c
          3.87471908191469       13.61417597653005        2.74601575252337      h
          1.13273337675207       13.63632407070856        4.61871577831466      h
         -0.02199235157559       20.67656946236531        0.00622158883396      c
  $eht charge=0 unpaired=4
  $end

  """
  
  let postOptimization = importFromXTB(string)
  return postOptimization
}

func createHDonTripod() -> [MRAtom] {
  let string = """
  $coord
         -5.43863209686787        8.99931234153102        0.37573117213197      c
         -6.28226253703411        9.42535908911745        2.21072906499995      h
         -5.52300000000000        5.62700000000000        0.03100000000000      s
         -6.66979644812175        9.75428261195748       -1.09886357576059      h
          2.39253177242971        8.99989231186873       -4.89257849897885      c
          4.28494728224871        9.75581956244755       -5.22037720523262      h
          1.22508760916199        9.42759495438994       -6.54017114056522      h
          2.73500000000000        5.62700000000000       -4.79900000000000      s
         -1.52781522942309        9.43950209761839       -2.26890147838626      c
         -2.61054105697015       10.16839570778971       -3.87281273155015      h
         -1.58879274288295        7.37324968468452       -2.35564371373371      h
          1.56724443567397       10.26409075206402        2.33797185525560      c
         -1.20795645333428        9.44120371684568        2.45968393097422      c
         -2.05519942120582       10.17197740370021        4.19875423140538      h
         -1.25380062818099        7.37505107032665        2.55743851072377      h
         -2.81034756782725       10.26513978699813        0.19435689254224      c
          2.72454448212142        9.43376798225276       -0.18175260122199      c
          2.82109694871340        7.36697627473520       -0.18965817259909      h
          4.65813167238318       10.15380738080069       -0.31792589407000      h
          1.23528016621639       10.26300788594403       -2.52434921496931      c
          1.45325507576254       13.11536547459521       -2.98962695771923      c
          0.44860151664923       13.61760095104962       -4.71776523268335      h
          3.42955301899489       13.63264869898430       -3.26275749835871      h
         -3.32151824418896       13.11683577535347        0.24015567372141      c
         -4.31085453344733       13.61854645249325        1.97710129567658      h
         -4.54972238541494       13.63544713414969       -1.33120878832033      h
         -0.00155706594041       14.77853394337277        0.00193967284183      ge
         -0.00152326465119       17.64078345956699        0.00139079787115      h
          3.03660428247295        9.00050580457293        4.52576724296407      c
          5.04691802951297        9.43161439367133        4.34395385840903      h
          2.78800000000000        5.62699999999999        4.76800000000000      s
          2.36882450891266        9.75231952656998        6.32830507804078      h
          1.86648426148262       13.11636912692699        2.75527194133684      c
          3.86630495184679       13.61555473880207        2.73525498547448      h
          1.12813885997985       13.63716844257628        4.60744848845599      h
  $eht charge=0 unpaired=3
  $end

  """
  
  let postOptimization = importFromXTB(string)
  return postOptimization
}
