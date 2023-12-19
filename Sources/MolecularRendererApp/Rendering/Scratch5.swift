//
//  Scratch5.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/18/23.
//

import Foundation
import HDL
import MolecularRenderer
import Numerics

// MARK: - Assembling Scenes for Still Photos

func createTransistorAtoms() -> [MRAtom] {
  var output: [MRAtom] = []
  let transistorLattice = createTransistor()
  var transistorAtoms = transistorLattice.entities.map(MRAtom.init)
  for i in transistorAtoms.indices {
    if transistorAtoms[i].element == 7 {
      transistorAtoms[i].element = 5
    }
    transistorAtoms[i].origin += SIMD3(5, -50, -50)
  }
  output += transistorAtoms
  return output
}

func createTransistor() -> Lattice<Hexagonal> {
  var latticeH = 48 / Constant(.hexagon) { .elemental(.silicon) }
  var latticeH2K = latticeH / Float(3).squareRoot()
  var latticeL = 48 / Constant(.prism) { .elemental(.silicon) }
  latticeH.round(.toNearestOrEven)
  latticeH2K.round(.toNearestOrEven)
  latticeL.round(.toNearestOrEven)
  
  // 1 gate
  // 5.6 million atoms
  return Lattice<Hexagonal> { h, k, l in
    let h2k = h + 2 * k
    Bounds { latticeH * h + latticeH2K * h2k + latticeL * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Concave {
        Concave {
          Origin { 1 * h + 1 * h2k + 1 * l }
          Plane { h }
          Plane { h2k }
          Plane { l }
        }
        Concave {
          Origin {
            (latticeH-1) * h + (latticeH2K-1) * h2k + (latticeL-1) * l
          }
          Plane { -h }
          Plane { -h2k }
          Plane { -l }
        }
      }
      Replace { .empty }
    }
    
    Volume {
      Origin { (latticeL-0.5) * l }
      Origin { (latticeH2K/2) * h2k }
      Concave {
        Plane { l }
        for directionH2K in [h2k, -h2k] {
          Convex {
            Origin { (latticeH2K/6) * directionH2K }
            Plane { -directionH2K }
          }
        }
      }
      
      // yellow color better represents that it's P-doped, contrasts with
      // blue from boron
      Replace { .atom(.sulfur) }
    }
    for directionH2K in [h2k, -h2k] {
      Volume {
        Origin { (latticeL-0.5) * l }
        Origin { (latticeH2K/2) * h2k }
        Concave {
          Plane { l }
          Origin { (latticeH2K/6) * directionH2K }
          Plane { directionH2K }
          Origin { (latticeH/2) * h }
          Plane { -h }
        }
        Replace { .atom(.nitrogen) }
      }
    }
  }
}

func createTransistorComparison() -> [MRAtom] {
  var output: [MRAtom] = []
  let gate1 = ServoArm.createNORGate()[0..<3]
  let masterGate = gate1.flatMap { $0.atoms }
  
  var masterMin: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
  var masterMax: SIMD3<Float> = -masterMin
  for i in masterGate.indices {
    let origin = masterGate[i].origin
    masterMin.replace(with: origin, where: origin .< masterMin)
    masterMax.replace(with: origin, where: origin .> masterMax)
  }
  print(masterMin, masterMax)
  let medianX = (masterMax.x + masterMin.x) / 2
  let medianY = (masterMax.y + masterMin.y) / 2
  var masterGate2 = masterGate
  for i in masterGate2.indices {
    var origin = masterGate2[i].origin
    let deltaX = origin.x - medianX
    let deltaY = origin.y - medianY
    origin.x = medianX - deltaX
    origin.y = medianY - deltaY
    masterGate2[i].origin = origin
  }
  
  // 48 / 6.73 = 7
  // 48 / 7.8 = 6
  // 48 / 2.4 = 20
  //
  // 840 gates
  // 12.3 million atoms
  var gateAddresses: [SIMD3<Int>] = []
  let widthX: Int = 7
  let widthY: Int = 6
  let widthZ: Int = 20
  for x in 0..<widthX {
    for y in 0..<widthY {
      gateAddresses.append(SIMD3(x, y, widthZ-1))
      if x == widthX-1 || y == widthY - 1 {
        for z in 1..<(widthZ-1) {
          gateAddresses.append(SIMD3(x, y, z))
        }
      } else {
        for z in (widthZ-2)..<(widthZ-1) {
          gateAddresses.append(SIMD3(x, y, z))
        }
      }
    }
  }
  
  for address in gateAddresses {
    let offset = SIMD3<Float>(address) * SIMD3(6.73, 7.8, 2.4)
    var copy = (address.x % 2 == 0) ? masterGate2 : masterGate
    for i in copy.indices {
      copy[i].origin += offset
    }
    output += copy
  }
  for i in output.indices {
    output[i].origin -= SIMD3(55, 50, 50)
  }
  
  output += createTransistorAtoms()
  return output
}

enum Slideshow {
  static func _01GoldSurface() -> [MRAtom] {
    var output: [MRAtom] = []
    let surface = Bootstrapping.Surface()
    output += surface.atoms
    return output
  }
  
  static func _02AFMAndTripods() -> [MRAtom] {
    var output: [MRAtom] = []
    let surface = Bootstrapping.Surface()
    var tripods: [Bootstrapping.Tripod] = []
    let tripodPositions = Bootstrapping.Tripod.createPositions(radius: 58) // 38
    for position in tripodPositions {
      tripods.append(Bootstrapping.Tripod(position: position))
    }
    let probe = Bootstrapping.Probe()
    output += surface.atoms
    for tripod in tripods {
      output += tripod.atoms
    }
    output += probe.atoms
    return output
  }
  
  static func _03RobotClaw() -> [MRAtom] {
    var output: [MRAtom] = []
    let surface = Bootstrapping.Surface()
    var tripods: [Bootstrapping.Tripod] = []
    let tripodPositions = Bootstrapping.Tripod.createPositions(radius: 58) // 38
    for position in tripodPositions {
      tripods.append(Bootstrapping.Tripod(position: position))
    }
    let probe = Bootstrapping.Probe()
    output += surface.atoms
    for tripod in tripods {
      output += tripod.atoms
    }
    output += probe.atoms.map {
      var copy = $0
      copy.origin.y += 2
      return copy
    }
    
    
    
    var claw = RobotArm.masterClaw
    claw.setCenterOfMass(.zero)
    
    claw.transform {
      var origin = $0.origin
      origin = SIMD3(origin.x, origin.z, -origin.y)
      $0.origin = origin
    }
    
    let box = claw.createBoundingBox()
    claw.atoms.removeAll(where: { $0.origin.z < 0 })
    let boxCenter = (box.1 + (box.0 + box.1) / 2) / 2
    claw.translate(offset: [0, 1.5, -boxCenter.z])
    
    output += claw.atoms
    return output
  }
  
  static func _04RobotArm() -> [MRAtom] {
    var output: [MRAtom] = []
    let robotArm = RobotArm(index: 0)
    func append(_ diamondoids: [Diamondoid]) {
      for element in diamondoids {
        output += element.atoms
      }
    }
    append([robotArm.claw])
    append(robotArm.hexagons)
    append(robotArm.bands)
    append(robotArm.controlRods)
    for tripod in robotArm.tripods {
      output += tripod
    }
    return output
  }
  
  static func _05AssemblyLine() -> [MRAtom] {
    var output: [MRAtom] = []
    let assemblyLine = AssemblyLine()
    output += assemblyLine.createAtoms()
    return output
  }
  
  static func _06Quadrant() -> [MRAtom] {
    var output: [MRAtom] = []
    var quadrant = Quadrant()
    quadrant.beltLinks = []
    quadrant.weldingStand = []
    output += quadrant.createAtoms()
    return output
  }
  
  static func _07BeltHeightMap() -> [MRAtom] {
    var output: [MRAtom] = []
    var quadrant = Quadrant()
    quadrant.beltLinks = []
    quadrant.weldingStand = []
    output += quadrant.createAtoms()
    
    for _ in 0..<300 {
      let x = Float.random(in: -70..<(14.9))
      let y = Quadrant.beltHeightMap(x)!
      let z: Float = -16
      output.append(MRAtom(origin: SIMD3(x, y, z), element: 8))
    }
    return output
  }
  
  static func _08BeltPlacement() -> [MRAtom] {
    var output: [MRAtom] = []
    var quadrant = Quadrant()
    output += quadrant.createAtoms()
    return output
  }
  
  static func _09HexagonDesign() -> [MRAtom] {
    let masterQuadrant = Quadrant()
    var quadrants: [Quadrant] = []
    quadrants.append(masterQuadrant)
    
    // Bypass Swift compiler warnings.
    let constructFullScene = Bool.random() ? false : false
    
    if constructFullScene {
      for i in 1..<4 {
        let angle = Float(i) * -90 * .pi / 180
        let quaternion = Quaternion<Float>(angle: angle, axis: [0, 1, 0])
        let basisX = quaternion.act(on: [1, 0, 0])
        let basisY = quaternion.act(on: [0, 1, 0])
        let basisZ = quaternion.act(on: [0, 0, 1])
        quadrants.append(masterQuadrant)
        quadrants[i].transform {
          var origin = $0.origin.x * basisX
          origin.addProduct($0.origin.y, basisY)
          origin.addProduct($0.origin.z, basisZ)
          $0.origin = origin
        }
      }
    }
    for i in quadrants.indices {
      quadrants[i].transform { $0.origin.y += 23.5 }
    }
    
    if constructFullScene {
      for i in quadrants.indices {
        var copy = quadrants[i]
        copy.transform { $0.origin.y *= -1 }
        quadrants.append(copy)
      }
    }
    var output = quadrants.flatMap { $0.createAtoms() }
    
    if constructFullScene {
      let floor = Floor(openCenter: true)
      output += floor.createAtoms().map {
        var copy = $0
        copy.origin = SIMD3(-copy.origin.z, copy.origin.y, copy.origin.x)
        return copy
      }
    }
    
    let lattice = createFloorHexagon(radius: 8.5, thickness: 10)
    var master = Diamondoid(lattice: lattice)
    master.setCenterOfMass(.zero)
    output += master.atoms
    return output
  }
  
  // _10HexagonPlacement()
  
  static func _10HexagonPlacement() -> [MRAtom] {
    let masterQuadrant = Quadrant()
    var quadrants: [Quadrant] = []
    quadrants.append(masterQuadrant)
    
    // Bypass Swift compiler warnings.
    let constructFullScene = Bool.random() ? false : false
    
    if constructFullScene {
      for i in 1..<4 {
        let angle = Float(i) * -90 * .pi / 180
        let quaternion = Quaternion<Float>(angle: angle, axis: [0, 1, 0])
        let basisX = quaternion.act(on: [1, 0, 0])
        let basisY = quaternion.act(on: [0, 1, 0])
        let basisZ = quaternion.act(on: [0, 0, 1])
        quadrants.append(masterQuadrant)
        quadrants[i].transform {
          var origin = $0.origin.x * basisX
          origin.addProduct($0.origin.y, basisY)
          origin.addProduct($0.origin.z, basisZ)
          $0.origin = origin
        }
      }
    }
    for i in quadrants.indices {
      quadrants[i].transform { $0.origin.y += 23.5 }
    }
    
    if constructFullScene {
      for i in quadrants.indices {
        var copy = quadrants[i]
        copy.transform { $0.origin.y *= -1 }
        quadrants.append(copy)
      }
    }
    var output = quadrants.flatMap { $0.createAtoms() }
    
    if constructFullScene || true {
      let floor = Floor(openCenter: true)
      output += floor.createAtoms().map {
        var copy = $0
        copy.origin = SIMD3(-copy.origin.z, copy.origin.y, copy.origin.x)
        return copy
      }
    }
    
    return output
  }
  
  static func _11QuadrantInstantiation() -> [MRAtom] {
    let masterQuadrant = Quadrant()
    var quadrants: [Quadrant] = []
    quadrants.append(masterQuadrant)
    
    // Bypass Swift compiler warnings.
    let constructFullScene = Bool.random() ? true : true
    
    if constructFullScene {
      for i in 1..<4 {
        let angle = Float(i) * -90 * .pi / 180
        let quaternion = Quaternion<Float>(angle: angle, axis: [0, 1, 0])
        let basisX = quaternion.act(on: [1, 0, 0])
        let basisY = quaternion.act(on: [0, 1, 0])
        let basisZ = quaternion.act(on: [0, 0, 1])
        quadrants.append(masterQuadrant)
        quadrants[i].transform {
          var origin = $0.origin.x * basisX
          origin.addProduct($0.origin.y, basisY)
          origin.addProduct($0.origin.z, basisZ)
          $0.origin = origin
        }
      }
    }
    for i in quadrants.indices {
      quadrants[i].transform { $0.origin.y += 23.5 }
    }
    
    if constructFullScene {
      for i in quadrants.indices {
        var copy = quadrants[i]
        copy.transform { $0.origin.y *= -1 }
        quadrants.append(copy)
      }
    }
    var output = quadrants.flatMap { $0.createAtoms() }
    
    if constructFullScene {
      let floor = Floor(openCenter: true)
      output += floor.createAtoms().map {
        var copy = $0
        copy.origin = SIMD3(-copy.origin.z, copy.origin.y, copy.origin.x)
        return copy
      }
    }
    
    return output
  }
  
  static func _12ServoGripperDesign() -> [MRAtom] {
    var output: [MRAtom] = []
    var part1s: [Diamondoid] = []
    var grippers: [Diamondoid] = []
    var connectors: [Diamondoid] = []
    
    let lattice1 = createServoArmPart1()
    let latticeGripper = createServoArmGripper()
    let latticeConnector = createServoArmConnector()
    part1s.append(Diamondoid(lattice: lattice1))
    grippers.append(Diamondoid(lattice: latticeGripper))
    connectors.append(Diamondoid(lattice: latticeConnector))
    connectors.append(connectors[0])
    grippers[0].translate(offset: [0, -4.15, -3.7])
    connectors[0].translate(offset: [-7, 6.5, -1.3])
    connectors[1].translate(offset: [-7, 14.5, -1.3])
    
    for part1 in part1s {
      output += part1.atoms
    }
    for gripper in grippers {
      output += gripper.atoms
    }
    for connector in connectors {
      output += connector.atoms
    }
    return output
  }
  
  static func _13ServoGripperReflection() -> [MRAtom] {
    // NOTE: Comment out the code that rotates the servo arm when running this.
    var output: [MRAtom] = []
    var arm = ServoArm()
    arm.hexagons.removeAll()
    arm.halfHexagons.removeAll()
    output += arm.createAtoms()
    return output
  }
  
  static func _14ServoGripperHexagons() -> [MRAtom] {
    var output: [MRAtom] = []
    var arm = ServoArm()
    output += arm.createAtoms()
    return output
  }
  
  // static func _15FinishedScene() -> [MRAtom] {}
}
