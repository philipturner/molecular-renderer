// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import MolecularRenderer
import Numerics

func createNanomachinery() -> [MRAtom] {
  // missing pieces:
  // - level 1:
  //   - housing (cubic Ge lattice)
  //   - chain-linked track depicting products being moved along
  //
  // - level 2:
  //   - rod that links controls for 3 assembly lines in SIMD fashion
  //   - larger assembly line in front of the rows of robot arms
  //
  // - level 3:
  //   - hexagonal centerpiece at the 3rd level of convergent assembly
  //   - mystery - what is the feature here? large multi-DOF manipulator?
  //     computer? decide when the time comes.
  
//  let assemblyLine = AssemblyLine()
//  return assemblyLine.createAtoms()
  
  // TODO: - Add function parameters for the location of different beams.
  let housing = createAssemblyHousing()
  return housing.entities.map(MRAtom.init)
}

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

func createAssemblyHousing() -> Lattice<Cubic> {
  Lattice<Cubic> { h, k, l in
    let spanY: Float = 20
    let spanZ: Float = 60
    let beamPositionY: Float = 5
    Bounds { 20 * h + spanY * k + spanZ * l }
    Material { .elemental(.germanium) }
    
    // Tasks:
    // - Design the general shape and functionality you want.
    // - Visualize the dimensions in the assembly.
    // - Make the ends of nearby beams agree in 3D, and remove difficult-to-
    //   passivate crystal surfaces, so it can be hydrogen-passivated.
    
    func _createBeam(
      principalAxis1: SIMD3<Float>,
      principalAxis2: SIMD3<Float>,
      thickness: Float
    ) {
      for negate1 in [false, true] {
        for negate2 in [false, true] {
          var direction: SIMD3<Float> = .zero
          direction += negate1 ? -principalAxis1 : principalAxis1
          direction += negate2 ? -principalAxis2 : principalAxis2
          Convex {
            Origin { thickness * direction }
            Plane { direction }
          }
        }
      }
    }
    
    func createBeamX() {
      Convex {
        Origin { 4 * (k + l) }
        Origin { beamPositionY * k }
        _createBeam(principalAxis1: k, principalAxis2: l, thickness: 2)
      }
    }
    
    func createBeamY() {
      Convex {
        Origin { 4 * (h + l) }
        _createBeam(principalAxis1: h, principalAxis2: l, thickness: 2)
      }
    }
    
    func createBeamZ() {
      Convex {
        Origin { 4 * (h + k) }
        Origin { beamPositionY * k }
        _createBeam(principalAxis1: h, principalAxis2: k, thickness: 2)
      }
    }
    
    Volume {
      Concave {
        createBeamX()
        createBeamY()
        createBeamZ()
        
        Origin { (spanZ - 4 - 2 * 2) * l }
        createBeamX()
        createBeamY()
      }
      
      Replace { .empty }
    }
  }
}

struct AssemblyLine {
  struct RobotArm {
    var claw: Diamondoid
    var hexagons: [Diamondoid] = []
    var bands: [Diamondoid] = []
    var controlRods: [Diamondoid] = []
    
    // Avoid compiling these multiple times. The hydrogenation during the
    // initializer for 'Diamondoid' is a known bottleneck.
    static let masterClaw: Diamondoid = {
      let clawLattice = createRobotClawLattice()
      return Diamondoid(lattice: clawLattice)
    }()
    static let masterBand: Diamondoid = {
      let bandLattice = createBandLattice()
      return Diamondoid(lattice: bandLattice)
    }()
    static let masterHexagon: Diamondoid = {
      let hexagonLattice = createHexagonLattice()
      return Diamondoid(lattice: hexagonLattice)
    }()
    static let masterHexagons: [Diamondoid] = {
      var hexagon = Self.masterHexagon
      hexagon.setCenterOfMass(.zero)
      hexagon.rotate(degrees: -90, axis: [1, 0, 0])
      hexagon.translate(offset: [0, 22, 0])
      
      var hexagons: [Diamondoid] = []
      for i in 0..<15 {
        var output = hexagon
        output.translate(offset: [0, Float(i) * 0.8, 0])
        output.rotate(degrees: Float(i) * 3, axis: [0, 1, 0])
        hexagons.append(output)
      }
      return hexagons
    }()
    
    static func createRods(index: Int) -> [Diamondoid] {
      let ratio =
      Float(3).squareRoot() *
      Constant(.hexagon) { .elemental(.carbon) }
      / Constant(.prism) { .elemental(.silicon) }
      let rodCellSpacing = Int((16 / ratio).rounded(.toNearestOrEven))
      
      let rodLattice = createControlRod(length: 70 - rodCellSpacing * index)
      var rod = Diamondoid(lattice: rodLattice)
      rod.setCenterOfMass(.zero)
      rod.rotate(degrees: 90, axis: [1, 0, 0])
      
      let box = rod.createBoundingBox()
      rod.translate(offset: [
        4.3 - box.1.x,
        22 - box.0.y,
        -3.5 - box.0.z
      ])
      rod.translate(offset: [0, 4 * Float(index), 0])
      let right = rod
      
      rod.translate(offset: [0, 1.3, 0])
      rod.transform { $0.origin.x = -$0.origin.x }
      let left = rod
      
      return [left, right]
    }
    
    init(index: Int) {
      claw = Self.masterClaw
      claw.setCenterOfMass(.zero)
      claw.translate(offset: [0, 0 - claw.createBoundingBox().0.y, 0])
      
      var band = Self.masterBand
      band.setCenterOfMass(.zero)
      band.rotate(degrees: -90, axis: [1, 0, 0])
      band.rotate(degrees: -90, axis: [0, 1, 0])
      do {
        let box = band.createBoundingBox()
        band.translate(offset: [6.4 - box.1.x, 2.4 - box.0.y, 0])
        bands.append(band)
        
        band.transform { $0.origin.x = -$0.origin.x }
        bands.append(band)
      }
      
      hexagons = Self.masterHexagons
      controlRods = Self.createRods(index: index)
      
      let siliconConstant = Constant(.prism) { .elemental(.silicon) }
      let offsetZ = Float(16 * index + 8) * siliconConstant
      claw.translate(offset: [0, 0, offsetZ])
      for i in bands.indices {
        bands[i].translate(offset: [0, 0, offsetZ])
      }
      for i in hexagons.indices {
        hexagons[i].translate(offset: [0, 0, offsetZ])
      }
      for i in controlRods.indices {
        controlRods[i].translate(offset: [0, 0, offsetZ])
      }
    }
  }
  
  var robotArms: [RobotArm] = []
  var roofPieces: [Diamondoid] = []
  
  init() {
    robotArms.append(RobotArm(index: 0))
    robotArms.append(RobotArm(index: 1))
    robotArms.append(RobotArm(index: 2))
    
    func makeRoofPieces(xCenter: Float, yHeight: Float) -> [Diamondoid] {
      let roofPieceLattice = createRoofPieceLattice(xCenter: xCenter)
      var roofPiece = Diamondoid(lattice: roofPieceLattice)
      roofPiece.setCenterOfMass(.zero)
      var output: [Diamondoid] = []
      
      let box = roofPiece.createBoundingBox()
      roofPiece.translate(
        offset: [0 - box.0.x, yHeight - box.0.y, -0.2 - box.0.z])
      output.append(roofPiece)
      
      for i in output.indices {
        var copy = output[i]
        copy.transform { $0.origin.x = -$0.origin.x }
        output.append(copy)
      }
      return output
    }
    roofPieces += makeRoofPieces(xCenter: 4.5, yHeight: -7)
    roofPieces += makeRoofPieces(xCenter: 7.5, yHeight: 17)
    roofPieces += makeRoofPieces(xCenter: 7.5, yHeight: 33)
  }
  
  func createAtoms() -> [MRAtom] {
    var output: [MRAtom] = []
    func append(_ diamondoids: [Diamondoid]) {
      for element in diamondoids {
        output += element.atoms
      }
    }
    for robotArm in robotArms {
      append([robotArm.claw])
      append(robotArm.hexagons)
      append(robotArm.bands)
      append(robotArm.controlRods)
    }
    append(roofPieces)
    return output
  }
}
