//
//  ConvergentAssemblyArchitecture3.swift
//  HardwareCatalog
//
//  Created by Philip Turner on 12/16/23.
//

import Foundation
import HDL
import MolecularRenderer
import Numerics

// MARK: - Data Structures

struct RobotArm {
  var claw: Diamondoid
  var hexagons: [Diamondoid] = []
  var bands: [Diamondoid] = []
  var controlRods: [Diamondoid] = []
  var tripods: [[MRAtom]] = []
  
  // Avoid compiling these multiple times.
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
    tripods = Self.createTripods(index: index)
    
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
    for i in tripods.indices {
      for j in tripods[i].indices {
        tripods[i][j].origin.y += -2 + 0.85 * 1 + 0.5 * 0.25
        tripods[i][j].origin.z += offsetZ
      }
    }
  }
  
  static func createRods(index: Int) -> [Diamondoid] {
    let ratio =
    Float(3).squareRoot() *
    Constant(.hexagon) { .elemental(.carbon) }
    / Constant(.prism) { .elemental(.silicon) }
    let rodCellSpacing = Int((16 / ratio).rounded(.toNearestOrEven))
    
    var output: [Diamondoid] = []
    for isLeft in [false, true] {
      let length = isLeft ? Int(84) : 79
      let rodLattice = createControlRod(
        length: length - rodCellSpacing * index)
      var rod = Diamondoid(lattice: rodLattice)
      rod.setCenterOfMass(.zero)
      rod.rotate(degrees: 90, axis: [1, 0, 0])
      
      let box = rod.createBoundingBox()
      rod.translate(offset: [
        4.3 - box.1.x,
        22 - box.0.y,
        -3.3 - box.0.z
      ])
      rod.translate(offset: [0, 3.9 * Float(index), 0])
      if isLeft {
        rod.translate(offset: [0, 1.3, 0])
        rod.transform { $0.origin.x = -$0.origin.x }
      }
      output.append(rod)
    }
    return output
  }
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    claw.transform(closure)
    for i in hexagons.indices {
      hexagons[i].transform(closure)
    }
    for i in bands.indices {
      bands[i].transform(closure)
    }
    for i in controlRods.indices {
      controlRods[i].transform(closure)
    }
    for i in tripods.indices {
      var newTripod = tripods[i]
      for j in tripods[i].indices {
        closure(&newTripod[j])
      }
      tripods[i] = newTripod
    }
  }
}

struct AssemblyLine {
  var robotArms: [RobotArm] = []
  var roofPieces: [Diamondoid] = []
  var housing: Diamondoid
  var buildPlates: [[MRAtom]] = []
  
  init() {
    robotArms.append(RobotArm(index: 0))
    robotArms.append(RobotArm(index: 1))
    robotArms.append(RobotArm(index: 2))
    
    roofPieces += Self.makeRoofPieces(xCenter: 4.5, yHeight: -6.75)
    roofPieces += Self.makeRoofPieces(xCenter: 7.5, yHeight: 17)
    roofPieces += Self.makeRoofPieces(xCenter: 7.5, yHeight: 33.5)
    
    let housingLattice = createAssemblyHousing(terminal: false)
    housing = Diamondoid(lattice: housingLattice)
    housing.translate(offset: [-14.25, -8, -5])
    
    for plateID in 0..<6 {
      var plate = createStage1BuildPlate(index: plateID)
      for atomID in plate.indices {
        plate[atomID].origin += SIMD3(
          0, -3.9, 2.6 + Float(plateID) * 5)
      }
      buildPlates.append(plate)
    }
  }
  
  static func makeRoofPieces(xCenter: Float, yHeight: Float) -> [Diamondoid] {
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
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    for i in robotArms.indices {
      robotArms[i].transform(closure)
    }
    for i in roofPieces.indices {
      roofPieces[i].transform(closure)
    }
    housing.transform(closure)
    for i in buildPlates.indices {
      var nextPlate = buildPlates[i]
      for j in nextPlate.indices {
        closure(&nextPlate[j])
      }
      buildPlates[i] = nextPlate
    }
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
      for tripod in robotArm.tripods {
        output += tripod
      }
    }
    append(roofPieces)
    append([housing])
    for buildPlate in buildPlates {
      output += buildPlate
    }
    return output
  }
}

struct Quadrant {
  var assemblyLines: [AssemblyLine] = []
  var spacerHousing: Diamondoid
  var backBoards: [Diamondoid] = []
  var broadcastRods: [Diamondoid] = []
  var beltLinks: [Diamondoid] = []
  var weldingStand: [MRAtom] = []
  
  init() {
    let masterAssemblyLine = AssemblyLine()
    let assemblyLineSpacing: Float = 18.2
    assemblyLines.append(masterAssemblyLine)
    for i in 1..<4 {
      let vector = SIMD3(Float(i) * assemblyLineSpacing, 0, 0)
      assemblyLines.append(masterAssemblyLine)
      assemblyLines[i].transform { $0.origin += vector }
    }
    
    let spacerOffset = SIMD3(Float(4) * assemblyLineSpacing, 0, 0)
    spacerHousing = masterAssemblyLine.housing
    spacerHousing.transform { $0.origin += spacerOffset }
    
    do {
      let housingAtoms = assemblyLines[0].housing.atoms + spacerHousing.atoms
      var min: SIMD3<Float> = .init(repeating: .greatestFiniteMagnitude)
      var max = -min
      for atom in housingAtoms {
        let origin = atom.origin
        min.replace(with: origin, where: origin .< min)
        max.replace(with: origin, where: origin .> max)
      }
      
      let translation: SIMD3<Float> = [
        -67.5 - min.x,
        0 - (max.y + min.y) / 2,
         -23.5 - max.z
      ]
      self.transform { $0.origin += translation }
    }
    
    backBoards = Self.createBackBoards()
    broadcastRods = Self.createBroadcastRods()
    beltLinks = Self.createBeltLinks()
    
    weldingStand = createWeldingStandScene()
    for i in weldingStand.indices {
      weldingStand[i].origin.y -= 23.5
    }
  }
  
  static func createBackBoards() -> [Diamondoid] {
    let lattice1 = createNewBackBoardLattice1()
    let lattice2 = createNewBackBoardLattice2()
    var diamondoid1 = Diamondoid(lattice: lattice1)
    var diamondoid3 = Diamondoid(lattice: lattice2)
    diamondoid1.translate(offset: SIMD3(-66, -22, -62.5))
    diamondoid3.translate(offset: SIMD3(-66, -22, -62.5))
    diamondoid3.translate(offset: SIMD3(0.05, 0, 0))
    var output = [diamondoid1, diamondoid3]
    
    var diamondoid2 = diamondoid1
    diamondoid2.translate(offset: SIMD3(18.2 / 2, 0, 0))
    let boundingBox = diamondoid2.createBoundingBox()
    let minX = boundingBox.0.x
    let maxX = boundingBox.1.x
    diamondoid2.transform {
      let xDelta = $0.origin.x - minX
      let newX = maxX - xDelta
      $0.origin.x = newX
    }
    for i in 0..<4 {
      var board1 = diamondoid2
      var board2 = diamondoid1
      let delta1 = SIMD3(Float(i) * 18.2, 0, 0)
      let delta2 = SIMD3(Float(i + 1) * 18.2, 0, 0)
      board1.transform { $0.origin += delta1 }
      board2.transform { $0.origin += delta2 }
      output += [board1, board2]
    }
    return output
  }
  
  static func createBroadcastRods() -> [Diamondoid] {
    let lattice = createBroadcastRod()
    var rod = Diamondoid(lattice: lattice)
    rod.setCenterOfMass(.zero)
    let rodBox = rod.createBoundingBox()
    rod.translate(offset: [
      -61.9 - rodBox.0.x,
       (30.55 - 23.5) - rodBox.0.y,
       -20.3 - rodBox.0.z
    ])
    
    var output: [Diamondoid] = []
    for j in 0..<2 {
      var copyJ = rod
      if j == 1 {
        let boundingBox = copyJ.createBoundingBox()
        let minY = boundingBox.0.y
        let maxY = boundingBox.1.y
        copyJ.transform {
          let deltaY = $0.origin.y - minY
          let newY = maxY - deltaY
          $0.origin.y = newY
        }
      }
      for i in 0..<3 {
        var spacingZ: Float = 79 - 84
        spacingZ *= Float(3).squareRoot() * Constant(.hexagon) {
          .elemental(.carbon)
        }
        var translation = SIMD3(
          0, Float(i) * 3.9, Float(j) * spacingZ)
        if j == 1 {
          translation.x += 7.6
        }
        
        var copy = copyJ
        copy.translate(offset: translation)
        output.append(copy)
      }
    }
    return output
  }
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    for i in assemblyLines.indices {
      assemblyLines[i].transform(closure)
    }
    spacerHousing.transform(closure)
    for i in backBoards.indices {
      backBoards[i].transform(closure)
    }
    for i in broadcastRods.indices {
      broadcastRods[i].transform(closure)
    }
    for i in beltLinks.indices {
      beltLinks[i].transform(closure)
    }
    for i in weldingStand.indices {
      closure(&weldingStand[i])
    }
  }
  
  func createAtoms() -> [MRAtom] {
    var output: [MRAtom] = []
    for assemblyLine in assemblyLines {
      output += assemblyLine.createAtoms()
    }
    output += spacerHousing.atoms
    for backBoard in backBoards {
      output += backBoard.atoms
    }
    for broadcastRod in broadcastRods {
      output += broadcastRod.atoms
    }
    for beltLink in beltLinks {
      output += beltLink.atoms
    }
    output += weldingStand
    return output
  }
}

struct Floor {
  var hexagons: [Diamondoid] = []
  
  // Avoid compiling this multiple times.
  static let masterHexagon: Diamondoid = {
    let lattice = createFloorHexagon(radius: 8.5, thickness: 10)
    var master = Diamondoid(lattice: lattice)
    master.setCenterOfMass(.zero)
    master.rotate(degrees: -90, axis: [1, 0, 0])
    return master
  }()
  
  init(openCenter: Bool) {
    let h: SIMD3<Float> = 17.75 * [1, 0, 0]
    let k: SIMD3<Float> = 17.75 * [-0.5, 0, 0.5 * Float(3).squareRoot()]
    
    for i in -10...10 {
      for j in -10...10 {
        var position = Float(i) * h + Float(j) * k
        position += 0.5 * h + 0.5 * k
        let squareRadius: Float = 65
        if any(position .< -squareRadius .| position .> squareRadius) {
          continue
        }
        
        if openCenter {
          let length = (position * position).sum().squareRoot()
          if length < 20 {
            continue
          }
        }
        
        var copy = Self.masterHexagon
        copy.transform { $0.origin += position }
        hexagons.append(copy)
      }
    }
  }
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    for i in hexagons.indices {
      hexagons[i].transform(closure)
    }
  }
  
  func createAtoms() -> [MRAtom] {
    var output: [MRAtom] = []
    for hexagon in hexagons {
      output += hexagon.atoms
    }
    return output
  }
}

struct ServoArm {
  var part1s: [Diamondoid] = []
  var grippers: [Diamondoid] = []
  var connectors: [Diamondoid] = []
  var norGate: [Diamondoid] = []
  var hexagons: [Diamondoid] = []
  var halfHexagons: [Diamondoid] = []
  var upperHexagons: [Diamondoid] = []
  
  init() {
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
    self.transform { $0.origin.x += 4 }
    
    do {
      var copy = self
      copy.transform { $0.origin.x = -$0.origin.x }
      part1s += copy.part1s
      grippers += copy.grippers
      connectors += copy.connectors
    }
    
    self.norGate = Self.createNORGate()
    self.norGate.removeLast()
    for i in norGate.indices {
      norGate[i].translate(offset: [-3.15, -8, 0.2])
    }
    for i in 0..<3 {
      var copy = norGate[i]
      copy.translate(offset: [0, 7.8, 0.0])
      norGate.append(copy)
    }
    do {
      let master = norGate
      for i in 1..<3 {
        for var diamondoid in master {
          diamondoid.translate(offset: [
            0, 0, -2.4 * Float(i)])
          norGate.append(diamondoid)
        }
      }
    }
    self.addHexagons()
    
    let rotationCenter: SIMD3<Float> = [0, -2, 0]
    
    func rotate(degrees: Float, axis: SIMD3<Float>) {
      let radians = degrees * .pi / 180
      let quaternion = Quaternion<Float>(angle: radians, axis: axis)
      let basis1 = quaternion.act(on: [1, 0, 0])
      let basis2 = quaternion.act(on: [0, 1, 0])
      let basis3 = quaternion.act(on: [0, 0, 1])
      self.transform {
        var delta = $0.origin - rotationCenter
        delta = basis1 * delta.x + basis2 * delta.y + basis3 * delta.z
        $0.origin = rotationCenter + delta
      }
    }
    rotate(degrees: 60, axis: [0, 1, 0])
    rotate(degrees: -20, axis: [1, 0, 0])
    rotate(degrees: -30, axis: [0, 1, 0])
  }
  
  mutating func addHexagons() {
    let latticeHexagon = createFloorHexagon(radius: 5, thickness: 5)
    var hexagon = Diamondoid(lattice: latticeHexagon)
    hexagon.setCenterOfMass(.zero)
    hexagon.translate(offset: [0, 15.7, -2.5])
    hexagons.append(hexagon)
  
    let hexagon2Atoms = hexagon.atoms.filter {
      $0.element != 1 && $0.x < 1e-3
    }
    let hexagon2 = Diamondoid(atoms: hexagon2Atoms)
  
    do {
      let h: SIMD3<Float> = 10.35 * [1, 0, 0]
      let k: SIMD3<Float> = 10.35 * [-0.5, Float(3).squareRoot()/2,  0]
      func add(
        _ hMultiplier: Int,
        _ kMultiplier: Int,
        _ hexagon: Diamondoid,
        flip: Bool
      ) -> Diamondoid {
        var copy = hexagon
        var translation: SIMD3<Float> = .zero
        translation += Float(hMultiplier) * h
        translation += Float(kMultiplier) * k
        copy.translate(offset: translation)
        if flip {
          copy.transform { $0.origin.x = -$0.origin.x }
        }
        return copy
      }
      halfHexagons.append(add(1, 1, hexagon2, flip: true))
      halfHexagons.append(add(1, 1, hexagon2, flip: false))
      hexagons.append(add(1, 2, hexagon, flip: false))
      halfHexagons.append(add(2, 3, hexagon2, flip: true))
      halfHexagons.append(add(2, 3, hexagon2, flip: false))
      hexagons.append(add(2, 4, hexagon, flip: false))
      
      func secondLayer(_ input: Diamondoid) -> Diamondoid {
        let h2k = (h + 2 * k) / 2
        let l: SIMD3<Float> = [0, 0, 1.8]
        let translation = h2k + l
        var copy = input
        copy.translate(offset: translation)
        return copy
      }
      func thirdLayer(_ input: Diamondoid) -> Diamondoid {
        let l: SIMD3<Float> = [0, 0, 3.6]
        var copy = input
        copy.translate(offset: l)
        return copy
      }
      
      let boundingBox = hexagons[0].createBoundingBox()
      let y = (boundingBox.0.y + boundingBox.1.y) / 2
      let upperHexagonAtoms = hexagons[0].atoms.filter {
        ($0.origin.y > y - 1e-3) && ($0.element != 1)
      }
      let upperHexagon = Diamondoid(atoms: upperHexagonAtoms)
      
      let thirdLayerHexagons = Array<Diamondoid>(hexagons[1...])
      let thirdLayerHalfHexagons = Array(halfHexagons)
      hexagons += hexagons[1..<2].map(secondLayer)
      upperHexagons += [secondLayer(upperHexagon)]
      halfHexagons += halfHexagons.map(secondLayer)
      hexagons += thirdLayerHexagons.map(thirdLayer)
      upperHexagons += [thirdLayer(upperHexagon)]
      halfHexagons += thirdLayerHalfHexagons.map(thirdLayer)
    }
  }
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    for i in part1s.indices {
      part1s[i].transform(closure)
    }
    for i in grippers.indices {
      grippers[i].transform(closure)
    }
    for i in connectors.indices {
      connectors[i].transform(closure)
    }
    for i in norGate.indices {
      norGate[i].transform(closure)
    }
    for i in hexagons.indices {
      hexagons[i].transform(closure)
    }
    for i in halfHexagons.indices {
      halfHexagons[i].transform(closure)
    }
    for i in upperHexagons.indices {
      upperHexagons[i].transform(closure)
    }
  }
  
  func createAtoms() -> [MRAtom] {
    var output: [MRAtom] = []
    for part1 in part1s {
      output += part1.atoms
    }
    for gripper in grippers {
      output += gripper.atoms
    }
    for connector in connectors {
      output += connector.atoms
    }
    for part in norGate {
      output += part.atoms
    }
    for hexagon in hexagons {
      output += hexagon.atoms
    }
    for halfHexagon in halfHexagons {
      output += halfHexagon.atoms
    }
    for upperHexagon in upperHexagons {
      output += upperHexagon.atoms
    }
    return output
  }
}

struct FactoryScene {
  var quadrants: [Quadrant] = []
  var floor: Floor?
  var servoArm: ServoArm?
  
  init() {
    let masterQuadrant = Quadrant()
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
    
    if constructFullScene {
      floor = Floor(openCenter: true)
      floor!.transform {
        $0.origin = SIMD3(-$0.origin.z, $0.origin.y, $0.origin.x)
      }
      servoArm = ServoArm()
    }
  }
  
  func createAtoms() -> [MRAtom] {
    var output: [MRAtom] = []
    for quadrant in quadrants {
      output += quadrant.createAtoms()
    }
    if let floor {
      output += floor.createAtoms()
    }
    if let servoArm {
      output += servoArm.createAtoms()
    }
    return output
  }
}

