//
//  ConvergentAssemblyArchitecture5.swift
//  HardwareCatalog
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
    let quadrant = Quadrant()
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
    let arm = ServoArm()
    output += arm.createAtoms()
    return output
  }
  
  static func _15FinishedScene() -> [MRAtom] {
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
    
    let arm = ServoArm()
    output += arm.createAtoms()
    return output
  }
}

enum Media {
  static func _Architecture() -> [MRAtom] {
    var output: [MRAtom] = []
    for plateID in 0..<7 {
      var plate: [MRAtom] = []
      if plateID < 6 {
        plate = createStage1BuildPlate(index: plateID)
      } else {
        let product = createBeltLinkProduct()
        plate = createBuildPlate(product: product, sideHydrogens: false)
      }
      var translation: SIMD3<Float> = .zero
      if plateID >= 6 {
        translation.y = -6.5
      } else if plateID >= 3 {
        translation.y = -3
      }
      
      translation.x =
      plateID >= 6 ? Float(0) :
      3 * Float((plateID % 3) - 1)
      
      let degrees1 =
      plateID >= 6 ? Float(20) :
      plateID >= 3 ? Float(40) : 70
      
      let degrees2 =
      plateID >= 6 ? Float(-45) :
      Float((plateID % 3) - 1) * -30
      
      let quaternion1 = Quaternion<Float>(
        angle: degrees1 * .pi / 180, axis: [1, 0, 0])
      let quaternion2 = Quaternion<Float>(
        angle: degrees2 * .pi / 180, axis: [0, 1, 0])
      var basis1 = quaternion1.act(on: [1, 0, 0])
      var basis2 = quaternion1.act(on: [0, 1, 0])
      var basis3 = quaternion1.act(on: [0, 0, 1])
      basis1 = quaternion2.act(on: basis1)
      basis2 = quaternion2.act(on: basis2)
      basis3 = quaternion2.act(on: basis3)
      
      for atomID in plate.indices {
        var origin = plate[atomID].origin
        origin.z = -origin.z
        origin = basis1 * origin.x + basis2 * origin.y + basis3 * origin.z
        origin += translation
        plate[atomID].origin = origin
      }
      output += plate
    }
    return output
  }
  
  static func _HousingPart1() -> [MRAtom] {
    var output: [MRAtom] = []
    
    let housingLattice = createAssemblyHousing(terminal: false)
    var housing1 = Diamondoid(lattice: housingLattice)
    housing1.translate(offset: [-14.25, -18, -45])
    
    var housing2 = housing1
    housing2.translate(offset: [20.2, 0, 0])
    
    output += housing1.atoms
    output += housing2.atoms
    return output
  }
  
  static func _HousingPart2() -> [MRAtom] {
    var output: [MRAtom] = []
    
    let housingLattice = createAssemblyHousing(terminal: false)
    var housing1 = Diamondoid(lattice: housingLattice)
    housing1.translate(offset: [-14.25, -18, -45])
    
    let degrees1: Float = 10
    let quaternion1 = Quaternion<Float>(
      angle: degrees1 * .pi / 180, axis: [0, 0, 1])
    let basis1 = quaternion1.act(on: [1, 0, 0])
    let basis2 = quaternion1.act(on: [0, 1, 0])
    let basis3 = quaternion1.act(on: [0, 0, 1])
    var housing2 = housing1
    housing2.transform {
      var origin = $0.origin
      origin = basis1 * origin.x + basis2 * origin.y + basis3 * origin.z
      $0.origin = origin
    }
    housing2.translate(offset: [23, 2.5, 0])
    
    output += housing1.atoms
    output += housing2.atoms
    return output
  }
  
  enum Crystolecule: Int, CaseIterable {
    case backBoard1 = 0
    case backBoard2
    case beltLink
    case broadcastRod
    case floorHexagon
    case geHousing
    case geCDodecagon
    case receiverRod0
    case receiverRod1
    case receiverRod2
    case receiverRod3
    case receiverRod4
    case receiverRod5
    case robotArmBand
    case robotArmClaw
    case robotArmRoof1
    case robotArmRoof2
    case servoArmConnector
    case servoArmGripper
    case servoArmHexagon1
    case servoArmHexagon2
    case servoArmHexagon3
    case servoArmPart1
    case weldingStand
    
    var description: String {
      switch self {
      case .backBoard1:
        return "Back Board (1)"
      case .backBoard2:
        return "Back Board (2)"
      case .beltLink:
        return "Belt Link"
      case .broadcastRod:
        return "Broadcast Rod"
      case .floorHexagon:
        return "Floor Hexagon"
      case .geHousing:
        return "Ge Housing"
      case .geCDodecagon:
        return "GeC Dodecagon"
      case .receiverRod0:
        return "Receiver Rod (0)"
      case .receiverRod1:
        return "Receiver Rod (1)"
      case .receiverRod2:
        return "Receiver Rod (2)"
      case .receiverRod3:
        return "Receiver Rod (3)"
      case .receiverRod4:
        return "Receiver Rod (4)"
      case .receiverRod5:
        return "Receiver Rod (5)"
      case .robotArmBand:
        return "Robot Arm Band"
      case .robotArmClaw:
        return "Robot Arm Claw"
      case .robotArmRoof1:
        return "Robot Arm Roof (1)"
      case .robotArmRoof2:
        return "Robot Arm Roof (2)"
      case .servoArmConnector:
        return "Servo Arm Connector"
      case .servoArmGripper:
        return "Servo Arm Gripper"
      case .servoArmHexagon1:
        return "Servo Arm Hexagon (1)"
      case .servoArmHexagon2:
        return "Servo Arm Hexagon (2)"
      case .servoArmHexagon3:
        return "Servo Arm Hexagon (3)"
      case .servoArmPart1:
        return "Servo Arm Part 1"
      case .weldingStand:
        return "Welding Stand"
      }
    }
  }
  
  static func reportBillOfMaterials(_ scene: FactoryScene) {
    // Track the remaining atoms to ensure the numbers add up 100%.
    var miscellaneousAtomCount = 0 // catalysts and products
    
    // MARK: - Gather Statistics
    
    var atoms: [Media.Crystolecule: Int] = [:]
    var instances: [Media.Crystolecule: Int] = [:]
    for key in Media.Crystolecule.allCases {
      instances[key] = 0
    }
    
    do {
      let beltLinkLattice = createBeltLink()
      let beltLink = Diamondoid(lattice: beltLinkLattice)
      atoms[.beltLink] = beltLink.atoms.count
    }
    
    do {
      let weldingStandLattice = createWeldingStand()
      let weldingStand = Diamondoid(lattice: weldingStandLattice)
      atoms[.weldingStand] = weldingStand.atoms.count
    }
    
    for quadrant in scene.quadrants {
      var minBoardSize: Int = .max
      var maxBoardSize: Int = .min
      for backBoard in quadrant.backBoards {
        minBoardSize = min(minBoardSize, backBoard.atoms.count)
        maxBoardSize = max(maxBoardSize, backBoard.atoms.count)
      }
      atoms[.backBoard1] = maxBoardSize
      atoms[.backBoard2] = minBoardSize
      for backBoard in quadrant.backBoards {
        if backBoard.atoms.count == maxBoardSize {
          instances[.backBoard1]! += 1
        } else if backBoard.atoms.count == minBoardSize {
          instances[.backBoard2]! += 1
        } else {
          fatalError("Unexpected board size.")
        }
      }
      
      // The final belt link structure has atoms not in the crystolecule.
      for beltLink in quadrant.beltLinks {
        let extraAtoms = beltLink.atoms.count - atoms[.beltLink]!
        precondition(extraAtoms > 0, "Unexpected atom count.")
        miscellaneousAtomCount += extraAtoms
        instances[.beltLink]! += 1
      }
      for broadcastRod in quadrant.broadcastRods {
        atoms[.broadcastRod] = broadcastRod.atoms.count
        instances[.broadcastRod]! += 1
      }
      
      // The final welding stand structure has atoms not in the crystolecule.
      do {
        let extraAtoms = quadrant.weldingStand.count - atoms[.weldingStand]!
        precondition(extraAtoms > 0, "Unexpected atom count.")
        miscellaneousAtomCount += extraAtoms
        instances[.weldingStand]! += 1
      }
      
      for assemblyLine in quadrant.assemblyLines {
        atoms[.geHousing] = assemblyLine.housing.atoms.count
        instances[.geHousing]! += 1
        
        let roofPieces = assemblyLine.roofPieces
        precondition(roofPieces.count == 6)
        precondition(roofPieces.allSatisfy {
          $0.atoms.count == roofPieces[0].atoms.count
        })
        atoms[.robotArmRoof1] = roofPieces[0].atoms.count
        atoms[.robotArmRoof2] = roofPieces.last!.atoms.count
        instances[.robotArmRoof1]! += 2
        instances[.robotArmRoof2]! += 4
        
        for plate in assemblyLine.buildPlates {
          miscellaneousAtomCount += plate.count
        }
        
        for robotArmID in assemblyLine.robotArms.indices {
          let robotArm = assemblyLine.robotArms[robotArmID]
          for dodecagon in robotArm.hexagons {
            atoms[.geCDodecagon] = dodecagon.atoms.count
            instances[.geCDodecagon]! += 1
          }
          for band in robotArm.bands {
            atoms[.robotArmBand] = band.atoms.count
            instances[.robotArmBand]! += 1
          }
          atoms[.robotArmClaw] = robotArm.claw.atoms.count
          instances[.robotArmClaw]! += 1
          
          let rods = robotArm.controlRods
          precondition(rods.count == 2)
          for rodID in 0..<2 {
            var crystolecule: Media.Crystolecule
            switch (robotArmID, rodID) {
            case (0, 0): crystolecule = .receiverRod0
            case (0, 1): crystolecule = .receiverRod1
            case (1, 0): crystolecule = .receiverRod2
            case (1, 1): crystolecule = .receiverRod3
            case (2, 0): crystolecule = .receiverRod4
            case (2, 1): crystolecule = .receiverRod5
            default: fatalError("This should never happen.")
            }
            atoms[crystolecule] = rods[rodID].atoms.count
            instances[crystolecule]! += 1
          }
          
          for tripod in robotArm.tripods {
            miscellaneousAtomCount += tripod.count
          }
        }
      }
      
      // Add the contribution from the spacer housing.
      precondition(quadrant.spacerHousing.atoms.count == atoms[.geHousing]!)
      instances[.geHousing]! += 1
    }
    
    for hexagon in scene.floor!.hexagons {
      atoms[.floorHexagon] = hexagon.atoms.count
      instances[.floorHexagon]! += 1
    }
    
    for part1 in scene.servoArm!.part1s {
      atoms[.servoArmPart1] = part1.atoms.count
      instances[.servoArmPart1]! += 1
    }
    for connector in scene.servoArm!.connectors {
      atoms[.servoArmConnector] = connector.atoms.count
      instances[.servoArmConnector]! += 1
    }
    for gripper in scene.servoArm!.grippers {
      atoms[.servoArmGripper] = gripper.atoms.count
      instances[.servoArmGripper]! += 1
    }
    for hexagon in scene.servoArm!.hexagons {
      atoms[.servoArmHexagon1] = hexagon.atoms.count
      instances[.servoArmHexagon1]! += 1
    }
    for halfHexagon in scene.servoArm!.halfHexagons {
      atoms[.servoArmHexagon2] = halfHexagon.atoms.count
      instances[.servoArmHexagon2]! += 1
    }
    for upperHexagon in scene.servoArm!.upperHexagons {
      atoms[.servoArmHexagon3] = upperHexagon.atoms.count
      instances[.servoArmHexagon3]! += 1
    }
    for diamondoid in scene.servoArm!.norGate {
      miscellaneousAtomCount += diamondoid.atoms.count
    }
    
    // MARK: - Report Statistics
    
    func formatNumber(_ number: Int) -> String {
      precondition(number >= 0)
      if number == 0 {
        return "0"
      }
      
      var chunks: [String] = []
      var result = number
      while result > 0 {
        // Account for the case where the sequence starts with zero.
        let chunk = "\(result)"
        if result >= 1000 {
          chunks.append(String(chunk.dropFirst(chunk.count - 3)))
        } else {
          chunks.append(chunk)
        }
        result /= 1000
      }
      return chunks.reversed().joined(separator: ",")
    }
    
    struct TableEntry {
      var part: String
      var atomCount: String
      var instanceCount: String
      var atomPercent: String = ""
    }
    var table: [TableEntry] = []
    table.append(
      TableEntry(
        part: "Part",
        atomCount: "Atom Count",
        instanceCount: "Part Count",
        atomPercent: "Atoms %"))
    
    for crystolecule in Media.Crystolecule.allCases {
      let entry = TableEntry(
        part: crystolecule.description,
        atomCount: formatNumber(atoms[crystolecule] ?? 0),
        instanceCount: formatNumber(instances[crystolecule]!))
      table.append(entry)
    }
    let partEntriesEnd = table.count
    
    // Gather Statistics
    var totalAtoms: Int = 0
    do {
      var compiledAtoms: Int = 0
      var compiledParts: Int = 0
      var instantiatedAtoms: Int = 0
      var instantiatedParts: Int = 0
      for crystolecule in Media.Crystolecule.allCases {
        let thisAtoms = atoms[crystolecule] ?? 0
        let thisInstances = instances[crystolecule]!
        compiledAtoms += thisAtoms
        compiledParts += 1
        instantiatedAtoms += thisAtoms * thisInstances
        instantiatedParts += thisInstances
      }
      table.append(
        TableEntry(
          part: "Compiled",
          atomCount: formatNumber(compiledAtoms),
          instanceCount: formatNumber(compiledParts)))
      table.append(
        TableEntry(
          part: "Instantiated",
          atomCount: formatNumber(instantiatedAtoms),
          instanceCount: formatNumber(instantiatedParts)))
      table.append(
        TableEntry(
          part: "Catalysts & Products",
          atomCount: formatNumber(miscellaneousAtomCount),
          instanceCount: "n/a"))
      
      totalAtoms = instantiatedAtoms + miscellaneousAtomCount
      table.append(
        TableEntry(
          part: "Total",
          atomCount: formatNumber(totalAtoms),
          instanceCount: formatNumber(instantiatedParts)))
      
      let propCompiled = Double(compiledAtoms) / Double(totalAtoms)
      let propInstanced = Double(instantiatedAtoms) / Double(totalAtoms)
      let propMisc = Double(miscellaneousAtomCount) / Double(totalAtoms)
      table[table.count - 4].atomPercent =
      String(format: "%.1f", 100 * propCompiled) + "%"
      table[table.count - 3].atomPercent =
      String(format: "%.1f", 100 * propInstanced) + "%"
      table[table.count - 2].atomPercent =
      String(format: "%.1f", 100 * propMisc) + "%"
      table[table.count - 1].atomPercent = "100.0%"
    }
    
    for entryID in 1..<partEntriesEnd {
      let thisAtoms = table[entryID].atomCount.filter { $0 != "," }
      let thisInstances = table[entryID].instanceCount.filter { $0 != "," }
      let proportion =
      Double(thisAtoms)! * Double(thisInstances)! / Double(totalAtoms)
      table[entryID].atomPercent =
      String(format: "%.1f", 100 * proportion) + "%"
    }
    
    var columnSize: SIMD4<Int> = .zero
    for entry in table {
      let size = SIMD4(entry.part.count,
                       entry.atomCount.count,
                       entry.instanceCount.count,
                       entry.atomPercent.count)
      columnSize.replace(with: size, where: size .> columnSize)
    }
    func pad(
      _ string: String, size: Int,
      alignLeft: Bool = false, alignRight: Bool = false
    ) -> String {
      let missing = size - string.count
      if alignLeft {
        return string + String(repeating: " ", count: missing)
      }
      if alignRight {
        return String(repeating: " ", count: missing) + string
      }
      let left = String(repeating: " ", count: missing / 2)
      let right = String(repeating: " ", count: missing - left.count)
      return left + string + right
    }
    
    func entryRepr(
      _ entry: TableEntry, alignLeft: Bool = false, alignRight: Bool = false
    ) -> String {
      let part = pad(
        entry.part, size: columnSize[0], alignLeft: alignLeft)
      let atomCount = pad(
        entry.atomCount, size: columnSize[1], alignRight: alignRight)
      let instanceCount = pad(
        entry.instanceCount, size: columnSize[2], alignRight: alignRight)
      let atomPercent = pad(
        entry.atomPercent, size: columnSize[3], alignRight: alignRight)
      
      var output: String = ""
      output += part + " | "
      output += atomCount + " | "
      output += instanceCount + " | "
      output += atomPercent
      return output
    }
    func dividerSection() -> String {
      String(repeating: "-", count: columnSize[0]) + " | " +
      String(repeating: "-", count: columnSize[1]) + " | " +
      String(repeating: "-", count: columnSize[2]) + " | " +
      String(repeating: "-", count: columnSize[3])
    }
    
    print()
    print(pad("Bill of Materials", size: dividerSection().count))
    print()
    print(entryRepr(table[0]))
    print(dividerSection())
    for entry in table[1..<partEntriesEnd] {
      print(entryRepr(entry, alignLeft: true, alignRight: true))
    }
    print(dividerSection())
    for summary in table[partEntriesEnd...] {
      print(entryRepr(summary, alignRight: true))
    }
    print()
  }
  
  // The function returns an optional value so it can function while partially
  // incomplete.
  static func createCrystoleculeAtoms(
    _ crystolecule: Media.Crystolecule
  ) -> (
    atoms: [MRAtom]?, offset: SIMD2<Float>?
  ) {
    func transformRod(_ rod: Diamondoid) -> Diamondoid {
      var copy = rod
      copy.setCenterOfMass(.zero)
      copy.transform {
        $0.origin = SIMD3($0.origin.x, -$0.origin.z, $0.origin.y)
      }
      return copy
    }
    func transformHexagon(_ hexagon: Diamondoid) -> Diamondoid {
      var copy = hexagon
      copy.setCenterOfMass(.zero)
      copy.transform {
        $0.origin = SIMD3($0.origin.y, -$0.origin.x, $0.origin.z)
      }
      return copy
    }
    
    switch crystolecule {
    case .backBoard1:
      let lattice1 = createNewBackBoardLattice1()
      let diamondoid1 = Diamondoid(lattice: lattice1)
      return (diamondoid1.atoms, SIMD2(10, 10))
    case .backBoard2:
      let lattice2 = createNewBackBoardLattice2()
      let diamondoid3 = Diamondoid(lattice: lattice2)
      return (diamondoid3.atoms, SIMD2(35, 10))
    case .beltLink:
      let lattice = createBeltLink()
      let masterBeltLink = Diamondoid(lattice: lattice)
      return (masterBeltLink.atoms, SIMD2(67, 20))
    case .broadcastRod:
      let lattice = createBroadcastRod()
      let rod = Diamondoid(lattice: lattice)
      return (rod.atoms, SIMD2(40, 35))
    case .floorHexagon:
      let lattice = createFloorHexagon(radius: 8.5, thickness: 10)
      var master = Diamondoid(lattice: lattice)
      master.setCenterOfMass(.zero)
      return (transformHexagon(master).atoms, SIMD2(23, 0))
    case .geHousing:
      let housingLattice = createAssemblyHousing(terminal: false)
      var housing1 = Diamondoid(lattice: housingLattice)
      housing1.setCenterOfMass(.zero)
      return (housing1.atoms, SIMD2(65, 10))
    case .geCDodecagon:
      let dodecagon = RobotArm.masterHexagon
      return (dodecagon.atoms, SIMD2(67, 42))
    case .receiverRod0:
      let rod = RobotArm.createRods(index: 0)[0]
      return (transformHexagon(transformRod(rod)).atoms, SIMD2(25, 42))
    case .receiverRod1:
      let rod = RobotArm.createRods(index: 0)[1]
      return (transformHexagon(transformRod(rod)).atoms, SIMD2(25, 47))
    case .receiverRod2:
      let rod = RobotArm.createRods(index: 1)[0]
      return (transformHexagon(transformRod(rod)).atoms, SIMD2(40, 39))
    case .receiverRod3:
      let rod = RobotArm.createRods(index: 1)[1]
      return (transformHexagon(transformRod(rod)).atoms, SIMD2(40, 44))
    case .receiverRod4:
      let rod = RobotArm.createRods(index: 2)[0]
      return (transformHexagon(transformRod(rod)).atoms, SIMD2(55, 42))
    case .receiverRod5:
      let rod = RobotArm.createRods(index: 2)[1]
      return (transformHexagon(transformRod(rod)).atoms, SIMD2(55, 47))
    case .robotArmBand:
      var band = RobotArm.masterBand
      band.transform {
        $0.origin = SIMD3($0.origin.x, $0.origin.z, $0.origin.y)
      }
      band.transform {
        $0.origin = SIMD3(-$0.origin.z, $0.origin.y, $0.origin.x)
      }
      return (band.atoms, SIMD2(43, 3))
    case .robotArmClaw:
      return (RobotArm.masterClaw.atoms, SIMD2(47, 12))
    case .robotArmRoof1:
      let pieces = AssemblyLine.makeRoofPieces(xCenter: 4.5, yHeight: -6.75)
      var output = transformRod(pieces[1])
      output.transform {
        $0.origin = SIMD3(-$0.origin.y, $0.origin.x, $0.origin.z)
      }
      return (output.atoms, SIMD2(52, 55))
    case .robotArmRoof2:
      let pieces = AssemblyLine.makeRoofPieces(xCenter: 7.5, yHeight: 17)
      var output = transformRod(pieces[1])
      output.transform {
        $0.origin = SIMD3(-$0.origin.y, $0.origin.x, $0.origin.z)
      }
      return (output.atoms, SIMD2(20, 55))
    case .servoArmConnector:
      let lattice = createServoArmConnector()
      let connector = Diamondoid(lattice: lattice)
      return (connector.atoms, SIMD2(72, 23))
    case .servoArmGripper:
      let lattice = createServoArmGripper()
      let gripper = Diamondoid(lattice: lattice)
      return (gripper.atoms, SIMD2(66.5, 2))
    case .servoArmHexagon1:
      let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
      var hexagon = Diamondoid(lattice: latticeHexagon)
      hexagon.setCenterOfMass(.zero)
      hexagon.translate(offset: [0, 15.7, -2.5])
      return (transformHexagon(hexagon).atoms, SIMD2(23, 15))
    case .servoArmHexagon2:
      let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
      var hexagon = Diamondoid(lattice: latticeHexagon)
      hexagon.setCenterOfMass(.zero)
      hexagon.translate(offset: [0, 15.7, -2.5])
      
      let hexagon2Atoms = hexagon.atoms.filter {
        $0.element != 1 && $0.x < 1e-3
      }
      let hexagon2 = Diamondoid(atoms: hexagon2Atoms)
      return (hexagon2.atoms, SIMD2(19, 27))
    case .servoArmHexagon3:
      let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
      var hexagon = Diamondoid(lattice: latticeHexagon)
      hexagon.setCenterOfMass(.zero)
      hexagon.translate(offset: [0, 15.7, -2.5])
      
      let boundingBox = hexagon.createBoundingBox()
      let y = (boundingBox.0.y + boundingBox.1.y) / 2
      let upperHexagonAtoms = hexagon.atoms.filter {
        ($0.origin.y > y - 1e-3) && ($0.element != 1)
      }
      let upperHexagon = Diamondoid(atoms: upperHexagonAtoms)
      return (transformHexagon(upperHexagon).atoms, SIMD2(27, 27))
    case .servoArmPart1:
      let lattice1 = createServoArmPart1()
      let diamondoid1 = Diamondoid(lattice: lattice1)
      return (diamondoid1.atoms, SIMD2(74.5, 2))
    case .weldingStand:
      let stand = createWeldingStand()
      let standDiamondoid = Diamondoid(lattice: stand)
      return (transformRod(standDiamondoid).atoms, SIMD2(75, 42.5))
    }
  }
  
  static func renderBillOfMaterials() -> [MRAtom] {
    struct Figure {
      var atoms: [MRAtom]
      var bounds: SIMD3<Float>
      var offset: SIMD2<Float>?
    }
    var figures: [Figure?] = []
    
    for crystolecule in Media.Crystolecule.allCases {
      let (atoms, offset) = createCrystoleculeAtoms(crystolecule)
      guard let atoms else {
        fatalError("This should never happen.")
        continue
      }
      
      var min = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
      var max = -min
      for i in atoms.indices {
        let origin = atoms[i].origin
        min.replace(with: origin, where: origin .< min)
        max.replace(with: origin, where: origin .> max)
      }
      let median = (min + max) / 2
      var centeringOperation = SIMD3<Float>.zero - median
      centeringOperation.z = 0 - max.z
      
      var outputAtoms = atoms
      for i in outputAtoms.indices {
        outputAtoms[i].origin += centeringOperation
      }
      figures.append(
        Figure(atoms: outputAtoms, bounds: max - min, offset: offset))
    }
    
    var output: [MRAtom] = []
    for figureID in figures.indices {
      guard let figure = figures[figureID] else {
        continue
      }
      // Use these default values until all crystolecules have an offset
      // manually assigned.
      let xProgress = Float(figureID % 5)
      let yProgress = Float(figureID / 5)
      var x = 10 * xProgress
      var y = 10 * yProgress
      if let offset = figure.offset {
        x = offset.x
        y = offset.y
      }
      for var atom in figure.atoms {
        atom.origin += SIMD3(x, y, 0)
        output.append(atom)
      }
    }
    return output
  }
}
