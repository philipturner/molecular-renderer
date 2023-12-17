//
//  Scratch3.swift
//  MolecularRendererApp
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
  }
}

struct AssemblyLine {
  var robotArms: [RobotArm] = []
  var roofPieces: [Diamondoid] = []
  var housing: Diamondoid
  
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
    roofPieces += makeRoofPieces(xCenter: 4.5, yHeight: -6.75)
    roofPieces += makeRoofPieces(xCenter: 7.5, yHeight: 17)
    roofPieces += makeRoofPieces(xCenter: 7.5, yHeight: 33.5)
    
    let housingLattice = createAssemblyHousing(terminal: false)
    housing = Diamondoid(lattice: housingLattice)
    housing.translate(offset: [-14.25, -8, -5])
  }
  
  mutating func transform(_ closure: (inout MRAtom) -> Void) {
    for i in robotArms.indices {
      robotArms[i].transform(closure)
    }
    for i in roofPieces.indices {
      roofPieces[i].transform(closure)
    }
    housing.transform(closure)
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
    append([housing])
    return output
  }
}

struct Quadrant {
  var assemblyLines: [AssemblyLine] = []
  var spacerHousing: Diamondoid
  var backBoards: [Diamondoid] = []
  var broadcastRods: [Diamondoid] = []
  
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
    
    do {
      let lattice1 = createNewBackBoardLattice1()
      let lattice2 = createNewBackBoardLattice2()
      var diamondoid1 = Diamondoid(lattice: lattice1)
      var diamondoid3 = Diamondoid(lattice: lattice2)
      diamondoid1.translate(offset: SIMD3(-66, -22, -62.5))
      diamondoid3.translate(offset: SIMD3(-66, -22, -62.5))
      diamondoid3.translate(offset: SIMD3(0.05, 0, 0))
      backBoards = [diamondoid1, diamondoid3]
      
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
        backBoards += [board1, board2]
      }
    }
    
    do {
      let lattice = createBroadcastRod()
      var rod = Diamondoid(lattice: lattice)
      rod.setCenterOfMass(.zero)
      let rodBox = rod.createBoundingBox()
      rod.translate(offset: [
        -61.9 - rodBox.0.x,
         (30.55 - 23.5) - rodBox.0.y,
         -20.3 - rodBox.0.z
      ])
      
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
          broadcastRods.append(copy)
        }
      }
    }
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
    return output
  }
}

struct Floor {
  var hexagons: [Diamondoid] = []
  
  // Avoid compiling this multiple times.
  static let masterHexagon: Diamondoid = {
    let lattice = createFloorHexagon(radius: 8.5)
    var master = Diamondoid(lattice: lattice)
    master.setCenterOfMass(.zero)
    master.rotate(degrees: -90, axis: [1, 0, 0])
    return master
  }()
  
  init(openCenter: Bool) {
    let h: SIMD3<Float> = 2 * 9 * [1, 0, 0]
    let k: SIMD3<Float> = 2 * 9 * [-0.5, 0, 0.5 * Float(3).squareRoot()]
    
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
