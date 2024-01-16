//
//  DiAdamantasilane.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 1/15/24.
//

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [Entity] {
  // Automate all data collection from xTB and MM4, including charges (via
  // xtb/cpu0/charges).
  
  let topology = createTopology(carbonCount: 6)
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = topology.atoms.map(\.atomicNumber)
  paramsDesc.bonds = topology.bonds
  let parametersBase = try! MM4Parameters(descriptor: paramsDesc)
  
  var adamantanes: [DiAdamantasilane] = []
  for i in 0..<3 {
    var adamantane = DiAdamantasilane()
    adamantane.bonds = topology.bonds
    
    if i == 2 {
      adamantane.atoms = xtbOptimizedStructure6
      adamantane.charges = xtbOptimizedCharges6
    } else {
      var parameters = parametersBase
      
      // Do something with the angles.
      var quaternarySilicons: Set<Int> = []
      for i in parameters.atoms.indices {
        if parameters.atoms.centerTypes[i] == .quaternary {
          quaternarySilicons.insert(i)
        }
      }
      for angleID in parameters.angles.indices.indices {
        let angle = parameters.angles.indices[angleID]
        let atomCodes = (0..<3).map { lane in
          parameters.atoms.codes[Int(angle[lane])]
        }
        
        if quaternarySilicons.contains(Int(angle[1])),
           atomCodes[0] == .silicon,
           atomCodes[1] == .silicon,
           atomCodes[2] == .silicon {
          //            print("\(parameters.angles.parameters), \(atomCodes), \(angle)")
          precondition(
            parameters.angles.parameters[angleID].equilibriumAngle == 109.5 ||
            parameters.angles.parameters[angleID].equilibriumAngle == 118)
          if i == 0 {
            parameters.angles.parameters[angleID].equilibriumAngle = 118
          } else {
            parameters.angles.parameters[angleID].equilibriumAngle = 109.5
          }
        }
      }
      adamantane.atoms = topology.atoms
      adamantane.charges = parameters.atoms.parameters.map(\.charge)
      
      var forceFieldDesc = MM4ForceFieldDescriptor()
      forceFieldDesc.parameters = parameters
      let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
      forceField.positions = adamantane.atoms.map(\.position)
      forceField.minimize()
      
      for i in forceField.positions.indices {
        adamantane.atoms[i].position = forceField.positions[i]
      }
    }
    adamantanes.append(adamantane)
  }
  
  var output: [Entity] = []
  for i in 0..<3 {
    var shift: SIMD3<Float>
    switch i {
    case 0: shift = -0.7 * SIMD3(1, 0, 0)
    case 1: shift = 0.0 * SIMD3(1, 0, 0)
    case 2: shift = 0.7 * SIMD3(1, 0, 0)
    default: fatalError()
    }
    shift += SIMD3(0, -0.5, -1.5)
    
    if i == 1 {
      // The revised parameter is the wrong one.
      continue
    }
    var atoms = adamantanes[i].atoms
    for atomID in atoms.indices {
      atoms[atomID].position += shift
    }
    output += atoms
  }
  
  // Report interesting bond lengths and angles for analysis.
  
  var sidewallHCharges = Statistic(
    tag: "H charge (on sidewall C)", decimalPlaces: 3)
  var bridgeheadHCharges = Statistic(
    tag: "H charge (on bridgehead C)", decimalPlaces: 3)
  var sidewallCCharges = Statistic(
    tag: "C charge (sidewall)", decimalPlaces: 3)
  var bridgeheadCCharges = Statistic(
    tag: "C charge (bridgehead)", decimalPlaces: 3)
  var bulkSiCharges = Statistic(
    tag: "Si charge (bulk)", decimalPlaces: 3)
  
  var sidewallSiSiBonds1 = Statistic(
    tag: "Si-Si (sidewall 1)", decimalPlaces: 3)
  var sidewallSiSiBonds2 = Statistic(
    tag: "Si-Si (sidewall 2)", decimalPlaces: 3)
  var sidewallSiSiBonds3 = Statistic(
    tag: "Si-Si (sidewall 3)", decimalPlaces: 3)
  var sidewallSiSiBonds4 = Statistic(
    tag: "Si-Si (sidewall 4)", decimalPlaces: 3)
  var bridgeheadSiSiBonds1 = Statistic(
    tag: "Si-Si (bridgehead 1)", decimalPlaces: 3)
  var bridgeheadSiSiBonds2 = Statistic(
    tag: "Si-Si (bridgehead 2)", decimalPlaces: 3)
  var bridgeheadSiSiBonds3 = Statistic(
    tag: "Si-Si (bridgehead 3)", decimalPlaces: 3)
  var bridgeheadSiSiBonds4 = Statistic(
    tag: "Si-Si (bridgehead 4)", decimalPlaces: 3)
  var bulkSiSiBonds = Statistic(
    tag: "Si-Si (bulk)", decimalPlaces: 3)
  var sidewallCSiBonds1 = Statistic(
    tag: "C-Si (sidewall 1)", decimalPlaces: 3)
  var sidewallCSiBonds2 = Statistic(
    tag: "C-Si (sidewall 2)", decimalPlaces: 3)
  var bridgeheadCSiBonds1 = Statistic(
    tag: "C-Si (bridgehead 1)", decimalPlaces: 3)
  var bridgeheadCSiBonds2 = Statistic(
    tag: "C-Si (bridgehead 2)", decimalPlaces: 3)
  
  var sidewallSiliconAngles1 = Statistic(
    tag: "Si-Si-Si (sidewall 1)", decimalPlaces: 1)
  var sidewallSiliconAngles2 = Statistic(
    tag: "Si-Si-Si (sidewall 2)", decimalPlaces: 1)
  var bridgeheadSiliconAngles1 = Statistic(
    tag: "Si-Si-Si (bridgehead 1)", decimalPlaces: 1)
  var bridgeheadSiliconAngles2 = Statistic(
    tag: "Si-Si-Si (bridgehead 2)", decimalPlaces: 1)
  var bridgeheadSiliconAngles3 = Statistic(
    tag: "Si-Si-Si (bridgehead 3)", decimalPlaces: 1)
  var bridgeheadSiliconAngles4 = Statistic(
    tag: "Si-Si-Si (bridgehead 4)", decimalPlaces: 1)
  
  var sidewallSiCSiAngles1 = Statistic(
    tag: "Si-C-Si (sidewall 1)", decimalPlaces: 1)
  var sidewallSiCSiAngles2 = Statistic(
    tag: "Si-C-Si (sidewall 2)", decimalPlaces: 1)
  var bridgeheadSiCSiAngles1 = Statistic(
    tag: "Si-C-Si (bridgehead 1)", decimalPlaces: 1)
  var bridgeheadSiCSiAngles2 = Statistic(
    tag: "Si-C-Si (bridgehead 2)", decimalPlaces: 1)
  var bridgeheadSiCSiAngles3 = Statistic(
    tag: "Si-C-Si (bridgehead 3)", decimalPlaces: 1)
  var bridgeheadSiCSiAngles4 = Statistic(
    tag: "Si-C-Si (bridgehead 4)", decimalPlaces: 1)
  
  var bulkSiliconAngles1 = Statistic(
    tag: "Si-Si-Si (bulk 1)", decimalPlaces: 1)
  var bulkSiliconAngles2 = Statistic(
    tag: "Si-Si-Si (bulk 2)", decimalPlaces: 1)
  var bulkSiliconAngles3 = Statistic(
    tag: "Si-Si-Si (bulk 3)", decimalPlaces: 1)
  var bulkSiliconAngles4 = Statistic(
    tag: "Si-Si-Si (bulk 4)", decimalPlaces: 1)
  var bulkSiliconAngles5 = Statistic(
    tag: "Si-Si-Si (bulk 5)", decimalPlaces: 1)
  var bulkSiliconAngles6 = Statistic(
    tag: "Si-Si-Si (bulk 6)", decimalPlaces: 1)
  var bulkSiliconAngles7 = Statistic(
    tag: "Si-Si-Si (bulk 7)", decimalPlaces: 1)
  var bulkSiliconAngles8 = Statistic(
    tag: "Si-Si-Si (bulk 8)", decimalPlaces: 1)
  
  var bulkCSiCAngles1 = Statistic(
    tag: "C-Si-C (bulk 1)", decimalPlaces: 1)
  var bulkCSiCAngles2 = Statistic(
    tag: "C-Si-C (bulk 2)", decimalPlaces: 1)
  var bulkCSiCAngles3 = Statistic(
    tag: "C-Si-C (bulk 3)", decimalPlaces: 1)
  var bulkCSiCAngles4 = Statistic(
    tag: "C-Si-C (bulk 4)", decimalPlaces: 1)
  var bulkCSiCAngles5 = Statistic(
    tag: "C-Si-C (bulk 5)", decimalPlaces: 1)
  var bulkCSiCAngles6 = Statistic(
    tag: "C-Si-C (bulk 6)", decimalPlaces: 1)
  var bulkCSiCAngles7 = Statistic(
    tag: "C-Si-C (bulk 7)", decimalPlaces: 1)
  var bulkCSiCAngles8 = Statistic(
    tag: "C-Si-C (bulk 8)", decimalPlaces: 1)
  
  var bulkCSiSiAngles1 = Statistic(
    tag: "C-Si-Si (bulk 1)", decimalPlaces: 1)
  var bulkCSiSiAngles2 = Statistic(
    tag: "C-Si-Si (bulk 2)", decimalPlaces: 1)
  var bulkCSiSiAngles3 = Statistic(
    tag: "C-Si-Si (bulk 3)", decimalPlaces: 1)
  var bulkCSiSiAngles4 = Statistic(
    tag: "C-Si-Si (bulk 4)", decimalPlaces: 1)
  var bulkCSiSiAngles5 = Statistic(
    tag: "C-Si-Si (bulk 5)", decimalPlaces: 1)
  var bulkCSiSiAngles6 = Statistic(
    tag: "C-Si-Si (bulk 6)", decimalPlaces: 1)
  var bulkCSiSiAngles7 = Statistic(
    tag: "C-Si-Si (bulk 7)", decimalPlaces: 1)
  var bulkCSiSiAngles8 = Statistic(
    tag: "C-Si-Si (bulk 8)", decimalPlaces: 1)
  
  let atomsToAtomsMap = topology.map(.atoms, to: .atoms)
  
  for forceFieldID in 0..<3 {
    var adamantane = adamantanes[forceFieldID]
    let parameters = parametersBase
    
    var sidewallSilicons: Set<Int> = []
    var bridgeheadSilicons: Set<Int> = []
    var quaternarySilicons: Set<Int> = []
    for i in parameters.atoms.indices {
      if parameters.atoms.atomicNumbers[i] == 14 {
        if parameters.atoms.centerTypes[i] == .primary {
          fatalError("This should never happen.")
        }
        if parameters.atoms.centerTypes[i] == .secondary {
          sidewallSilicons.insert(i)
        }
        if parameters.atoms.centerTypes[i] == .tertiary {
          bridgeheadSilicons.insert(i)
        }
        if parameters.atoms.centerTypes[i] == .quaternary {
          quaternarySilicons.insert(i)
        }
      }
    }
    
    for atomID in parameters.atoms.indices {
      let charge = adamantane.charges[atomID]
      switch parameters.atoms.codes[atomID] {
      case .hydrogen:
        let mappedAtomID = Int(atomsToAtomsMap[atomID].first!)
        guard parameters.atoms.atomicNumbers[mappedAtomID] == 6 else {
          continue
        }
        switch parameters.atoms.centerTypes[mappedAtomID]! {
        case .secondary:
          sidewallHCharges.append(charge, forceFieldID: forceFieldID)
        case .tertiary:
          bridgeheadHCharges.append(charge, forceFieldID: forceFieldID)
        default: fatalError()
        }
      case .alkaneCarbon, .cyclopentaneCarbon:
        switch parameters.atoms.centerTypes[atomID]! {
        case .secondary:
          sidewallCCharges.append(charge, forceFieldID: forceFieldID)
        case .tertiary:
          bridgeheadCCharges.append(charge, forceFieldID: forceFieldID)
        default: fatalError()
        }
      case .silicon:
        if parameters.atoms.centerTypes[atomID]! == .quaternary {
          bulkSiCharges.append(charge, forceFieldID: forceFieldID)
        }
      default:
        fatalError()
      }
    }
    
    for bondID in parameters.bonds.indices.indices {
      let bond = parameters.bonds.indices[bondID]
      let positions = (0..<2).map { lane in
        let atomID = Int(bond[lane])
        return adamantane.atoms[atomID].position
      }
      let atomicNumbers = (0..<2).map { lane in
        let atomID = Int(bond[lane])
        return adamantane.atoms[atomID].atomicNumber
      }
      
      var delta = positions[1] - positions[0]
      let bondLength = 10 * (delta * delta).sum().squareRoot()
      
      var bulkSiliconID = -1
      var otherAtomID = -1
      if quaternarySilicons.contains(Int(bond[0])) {
        bulkSiliconID = Int(bond[0])
        otherAtomID = Int(bond[1])
      } else if quaternarySilicons.contains(Int(bond[1])) {
        bulkSiliconID = Int(bond[1])
        otherAtomID = Int(bond[0])
      } else {
        continue
      }
      
      if atomicNumbers.contains(1) {
        continue
      }
      let otherAtomType = parameters.atoms.centerTypes[otherAtomID]!
      if atomicNumbers.contains(6) {
        if otherAtomType == .secondary {
          if sidewallCSiBonds1.count[forceFieldID] < 1 {
            sidewallCSiBonds1.append(bondLength, forceFieldID: forceFieldID)
          } else if sidewallCSiBonds2.count[forceFieldID] < 1 {
            sidewallCSiBonds2.append(bondLength, forceFieldID: forceFieldID)
          }
        } else if otherAtomType == .tertiary {
          if bridgeheadCSiBonds1.count[forceFieldID] < 1 {
            bridgeheadCSiBonds1.append(bondLength, forceFieldID: forceFieldID)
          } else if bridgeheadCSiBonds2.count[forceFieldID] < 1 {
            bridgeheadCSiBonds2.append(bondLength, forceFieldID: forceFieldID)
          }
        } else {
          fatalError()
        }
      }
      else {
        if otherAtomType == .secondary {
          if sidewallSiSiBonds1.count[forceFieldID] < 1 {
            sidewallSiSiBonds1.append(bondLength, forceFieldID: forceFieldID)
          } else if sidewallSiSiBonds2.count[forceFieldID] < 1 {
            sidewallSiSiBonds2.append(bondLength, forceFieldID: forceFieldID)
          } else if sidewallSiSiBonds3.count[forceFieldID] < 1 {
            sidewallSiSiBonds3.append(bondLength, forceFieldID: forceFieldID)
          } else if sidewallSiSiBonds4.count[forceFieldID] < 1 {
            sidewallSiSiBonds4.append(bondLength, forceFieldID: forceFieldID)
          }
        } else if otherAtomType == .tertiary {
          if bridgeheadSiSiBonds1.count[forceFieldID] < 1 {
            bridgeheadSiSiBonds1.append(bondLength, forceFieldID: forceFieldID)
          } else if bridgeheadSiSiBonds2.count[forceFieldID] < 1 {
            bridgeheadSiSiBonds2.append(bondLength, forceFieldID: forceFieldID)
          } else if bridgeheadSiSiBonds3.count[forceFieldID] < 1 {
            bridgeheadSiSiBonds3.append(bondLength, forceFieldID: forceFieldID)
          } else if bridgeheadSiSiBonds4.count[forceFieldID] < 1 {
            bridgeheadSiSiBonds4.append(bondLength, forceFieldID: forceFieldID)
          }
        } else if otherAtomType == .quaternary {
          precondition(bulkSiSiBonds.count[forceFieldID] == 0)
          bulkSiSiBonds.append(bondLength, forceFieldID: forceFieldID)
        } else {
          fatalError()
        }
      }
    }
    
    for angleID in parameters.angles.indices.indices {
      let angle = parameters.angles.indices[angleID]
      let positions = (0..<3).map { lane in
        let atomID = Int(angle[lane])
        return adamantane.atoms[atomID].position
      }
      let atomicNumbers = (0..<3).map { lane in
        let atomID = Int(angle[lane])
        return adamantane.atoms[atomID].atomicNumber
      }
      
      var delta10 = positions[0] - positions[1]
      var delta12 = positions[2] - positions[1]
      delta10 /= (delta10 * delta10).sum().squareRoot()
      delta12 /= (delta12 * delta12).sum().squareRoot()
      
      let dotProduct = (delta10 * delta12).sum()
      let angleRadians = Float.acos(dotProduct)
      let angleDegrees = angleRadians * 180 / .pi
      
      let centerID = Int(angle[1])
      
      if atomicNumbers[1] == 6,
         quaternarySilicons.contains(Int(angle[0])) ||
          quaternarySilicons.contains(Int(angle[2])) {
        if atomicNumbers[0] == 14, atomicNumbers[2] == 14 {
          if parameters.atoms.centerTypes[centerID] == .secondary {
            if sidewallSiCSiAngles1.count[forceFieldID] < 1 {
              sidewallSiCSiAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if sidewallSiCSiAngles2.count[forceFieldID] < 1 {
              sidewallSiCSiAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            }
          } else if parameters.atoms.centerTypes[centerID] == .tertiary {
            if bridgeheadSiCSiAngles1.count[forceFieldID] < 1 {
              bridgeheadSiCSiAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bridgeheadSiCSiAngles2.count[forceFieldID] < 1 {
              bridgeheadSiCSiAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bridgeheadSiCSiAngles3.count[forceFieldID] < 1 {
              bridgeheadSiCSiAngles3.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bridgeheadSiCSiAngles4.count[forceFieldID] < 1 {
              bridgeheadSiCSiAngles4.append(angleDegrees, forceFieldID: forceFieldID)
            }
          }
        }
      }
      
      else if atomicNumbers[1] == 14,
              quaternarySilicons.contains(Int(angle[0])) ||
          quaternarySilicons.contains(Int(angle[1])) ||
          quaternarySilicons.contains(Int(angle[2])) {
        if atomicNumbers[0] == 14, atomicNumbers[2] == 14 {
          if sidewallSilicons.contains(centerID) {
            if sidewallSiliconAngles1.count[forceFieldID] < 1 {
              sidewallSiliconAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if sidewallSiliconAngles2.count[forceFieldID] < 1 {
              sidewallSiliconAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            }
          }
          if bridgeheadSilicons.contains(centerID) {
            if bridgeheadSiliconAngles1.count[forceFieldID] < 1 {
              bridgeheadSiliconAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bridgeheadSiliconAngles2.count[forceFieldID] < 1 {
              bridgeheadSiliconAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bridgeheadSiliconAngles3.count[forceFieldID] < 1 {
              bridgeheadSiliconAngles3.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bridgeheadSiliconAngles4.count[forceFieldID] < 1 {
              bridgeheadSiliconAngles4.append(angleDegrees, forceFieldID: forceFieldID)
            }
          }
          if quaternarySilicons.contains(centerID) {
            if bulkSiliconAngles1.count[forceFieldID] < 1 {
              bulkSiliconAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles2.count[forceFieldID] < 1 {
              bulkSiliconAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles3.count[forceFieldID] < 1 {
              bulkSiliconAngles3.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles4.count[forceFieldID] < 1 {
              bulkSiliconAngles4.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles5.count[forceFieldID] < 1 {
              bulkSiliconAngles5.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles6.count[forceFieldID] < 1 {
              bulkSiliconAngles6.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles7.count[forceFieldID] < 1 {
              bulkSiliconAngles7.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkSiliconAngles8.count[forceFieldID] < 1 {
              bulkSiliconAngles8.append(angleDegrees, forceFieldID: forceFieldID)
            }
          }
        }
        
        else if atomicNumbers[0] == 6, atomicNumbers[2] == 6 {
          if quaternarySilicons.contains(centerID) {
            if bulkCSiCAngles1.count[forceFieldID] < 1 {
              bulkCSiCAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles2.count[forceFieldID] < 1 {
              bulkCSiCAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles3.count[forceFieldID] < 1 {
              bulkCSiCAngles3.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles4.count[forceFieldID] < 1 {
              bulkCSiCAngles4.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles5.count[forceFieldID] < 1 {
              bulkCSiCAngles5.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles6.count[forceFieldID] < 1 {
              bulkCSiCAngles6.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles7.count[forceFieldID] < 1 {
              bulkCSiCAngles7.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiCAngles8.count[forceFieldID] < 1 {
              bulkCSiCAngles8.append(angleDegrees, forceFieldID: forceFieldID)
            }
          }
        }
        
        else if atomicNumbers.contains(6), !atomicNumbers.contains(1) {
          if quaternarySilicons.contains(centerID) {
            if bulkCSiSiAngles1.count[forceFieldID] < 1 {
              bulkCSiSiAngles1.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles2.count[forceFieldID] < 1 {
              bulkCSiSiAngles2.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles3.count[forceFieldID] < 1 {
              bulkCSiSiAngles3.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles4.count[forceFieldID] < 1 {
              bulkCSiSiAngles4.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles5.count[forceFieldID] < 1 {
              bulkCSiSiAngles5.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles6.count[forceFieldID] < 1 {
              bulkCSiSiAngles6.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles7.count[forceFieldID] < 1 {
              bulkCSiSiAngles7.append(angleDegrees, forceFieldID: forceFieldID)
            } else if bulkCSiSiAngles8.count[forceFieldID] < 1 {
              bulkCSiSiAngles8.append(angleDegrees, forceFieldID: forceFieldID)
            }
          }
        }
      }
    }
  }
  
  /*
   Should be exact same as before
   
   |                         | MM3(2000) | MM4(2024) | GFN2-xTB |
   | ----------------------- | ------ | ------ | ------ |
   | Si-Si-Si (sidewall)     |  108.4 |  107.8 |  110.9 |
   | Si-Si-Si (bridgehead 1) |  111.7 |  111.0 |  113.4 |
   | Si-Si-Si (bridgehead 2) |  102.3 |  104.6 |  101.4 |
   | Si-Si-Si (bulk 1)       |  108.2 |  106.4 |  107.0 |
   | Si-Si-Si (bulk 2)       |  112.0 |  108.9 |  111.2 |
   | Si-Si-Si (bulk 3)       |  112.0 |  108.9 |  111.2 |
   | Si-Si-Si (bulk 4)       |  108.2 |  106.4 |  107.0 |
   | Si-Si-Si (bulk 5)       | nan    | nan    | nan    |
   | Si-Si-Si (bulk 6)       | nan    | nan    | nan    |
   | Si-Si-Si (bulk 7)       | nan    | nan    | nan    |
   | Si-Si-Si (bulk 8)       | nan    | nan    | nan    |
   */
  
  // Write a Markdown table directly to the console.
  
  let statistics = [
    sidewallHCharges,
    bridgeheadHCharges,
    sidewallCCharges,
    bridgeheadCCharges,
    bulkSiCharges,
    
    sidewallSiSiBonds1,
    sidewallSiSiBonds2,
//    sidewallSiSiBonds3,
//    sidewallSiSiBonds4,
    bridgeheadSiSiBonds1,
    bridgeheadSiSiBonds2,
//    bridgeheadSiSiBonds3,
//    bridgeheadSiSiBonds4,
    bulkSiSiBonds,
    sidewallCSiBonds1,
    sidewallCSiBonds2,
    bridgeheadCSiBonds1,
    bridgeheadCSiBonds2,
    
    sidewallSiliconAngles1,
    sidewallSiliconAngles2,
    bridgeheadSiliconAngles1,
    bridgeheadSiliconAngles2,
    bridgeheadSiliconAngles3,
    bridgeheadSiliconAngles4,
    sidewallSiCSiAngles1,
    sidewallSiCSiAngles2,
    bridgeheadSiCSiAngles1,
    bridgeheadSiCSiAngles2,
    bridgeheadSiCSiAngles3,
    bridgeheadSiCSiAngles4,
    bulkSiliconAngles1,
    bulkSiliconAngles2,
    bulkSiliconAngles3,
    bulkSiliconAngles4,
    bulkSiliconAngles5,
    bulkSiliconAngles6,
    bulkSiliconAngles7,
    bulkSiliconAngles8,
    bulkCSiCAngles1,
    bulkCSiCAngles2,
    bulkCSiCAngles3,
    bulkCSiCAngles4,
    bulkCSiCAngles5,
    bulkCSiCAngles6,
    bulkCSiCAngles7,
    bulkCSiCAngles8,
    bulkCSiSiAngles1,
    bulkCSiSiAngles2,
    bulkCSiSiAngles3,
    bulkCSiSiAngles4,
    bulkCSiSiAngles5,
    bulkCSiSiAngles6,
    bulkCSiSiAngles7,
    bulkCSiSiAngles8,
    
  ]
  
  var characterCounts: SIMD4<Int> = .zero
  for statistic in statistics {
    print("statistic: \(statistic.count)")
    characterCounts[0] = max(characterCounts[0], statistic.tag.count)
    for (i, description) in statistic.descriptions.enumerated() {
      characterCounts[1 + i] = max(characterCounts[1 + i], description.count)
    }
  }
  print(
    "|",
    String(repeating: " ", count: characterCounts[0]),
    "| 118° | 109.5° | GFN2-xTB |")
  do {
    var line = "|"
    for lane in 0..<4 {
      line += " "
      line += String(repeating: "-", count: characterCounts[lane])
      line += " |"
    }
    print(line)
  }
  for statistic in statistics {
    var tag = statistic.tag
    while tag.count < characterCounts[0] {
      tag += " "
    }
    var line = "| \(tag) |"
    
    for lane in 0..<3 {
      var description = statistic.descriptions[lane]
      while description.count < characterCounts[1 + lane] {
        description += " "
      }
      line += " \(description) |"
    }
    print(line)
  }
  
  return output
}


struct DiAdamantasilane {
  var atoms: [Entity] = []
  var bonds: [SIMD2<UInt32>] = []
  var charges: [Float] = []
  
  
}

struct Statistic {
  var tag: String
  var decimalPlaces: Int
  var sum: SIMD3<Float> = .zero
  var count: SIMD3<Int> = .zero
  
  mutating func append(_ value: Float, forceFieldID: Int) {
    sum[forceFieldID] += value
    count[forceFieldID] += 1
  }
  
  var average: SIMD3<Float> {
    sum / SIMD3<Float>(count)
  }
  
  var descriptions: [String] {
    var output: [String] = []
    for lane in 0..<3 {
      var string = String(format: "%.\(decimalPlaces)f", average[lane])
      if average[lane] >= 0 {
        string = " " + string
      }
      output.append(string)
    }
    return output
  }
}

// NOTE: Cached build products for xTB-generated structures are located at:
// https://gist.github.com/philipturner/ffa077dce47ed738c3ead04cc8c9f1a0
//
// First ran through GFN-FF to accelerate convergence. Then ran through xTB to
// maximize accuracy.
//
// Artifacts:
// - xtbOptimizedStructure\(carbonCount)
// - xtbOptimizedCharges\(carbonCount)

func createTopology(carbonCount: Int) -> Topology {
  let lattice = Lattice<Cubic> { h, k, l in
    Bounds { 4 * h + 4 * k + 4 * l }
    Material { .elemental(.silicon) }
    
    Volume {
      Origin { 2 * h + 2 * k + 2 * l }
      Origin { 0.25 * (h + k - l) }
      
      // Remove the front plane.
      Convex {
        Origin { 0.25 * (h + k + l) }
        Plane { h + k + l }
      }
      
      func triangleCut(sign: Float) {
        Convex {
          Origin { 0.25 * sign * (h - k - l) }
          Plane { sign * (h - k / 2 - l / 2) }
        }
        Convex {
          Origin { 0.25 * sign * (k - l - h) }
          Plane { sign * (k - l / 2 - h / 2) }
        }
        Convex {
          Origin { 0.25 * sign * (l - h - k) }
          Plane { sign * (l - h / 2 - k / 2) }
        }
      }
      
      // Remove three sides forming a triangle.
      triangleCut(sign: +1)
      
      // Remove their opposites.
      triangleCut(sign: -1)
      
      // Remove the back plane.
      Convex {
        Origin { -0.25 * (h + k + l) }
        Plane { -(h + k + l) }
      }
      
      Replace { .empty }
      
      if carbonCount >= 2 {
        Volume {
          Origin { 0.3 * k }
          Plane { k }
          Replace { .atom(.carbon) }
        }
      }
      
      if carbonCount >= 4 {
        Volume {
          Origin { 0.3 * h }
          Plane { h }
          Replace { .atom(.carbon) }
        }
      }
      
      if carbonCount >= 6 {
        Volume {
          Origin { 0.2 * (-h - k + l) }
          Plane { (-h - k + l)  }
          Replace { .atom(.carbon) }
        }
      }
    }
  }
  
  let atoms = lattice.atoms
  let lastPosition1 = atoms[atoms.count - 2].position
  let lastPosition2 = atoms[atoms.count - 1].position
  
  var axis = lastPosition2 - lastPosition1
  axis /= (axis * axis).sum().squareRoot()
  let midPoint = (lastPosition1 + lastPosition2) / 2
  let rotation = Quaternion<Float>(angle: .pi, axis: axis)
  
  var averagePosition: SIMD3<Float> = .zero
  for atom in atoms {
    averagePosition += atom.position
  }
  averagePosition /= Float(atoms.count)
  
  var stretchingDirection = averagePosition - midPoint
  stretchingDirection /= (
    stretchingDirection * stretchingDirection).sum().squareRoot()
  
  var axisX = -stretchingDirection
  let axisY = axis
  let axisZ = cross_platform_cross(axisX, axisY)
  axisX = cross_platform_cross(axisY, axisZ)
  
  // Generate the actual atoms.
  
  var actualAtoms = Array(atoms[(atoms.count - 2)...])
  
  // Merge the two mirror-image adamantanes and rotate them, so the pair of
  // quaternary silicons points vertically.
  for halfID in 0..<2 {
    for var atom in atoms[..<(atoms.count - 2)] {
      var delta = atom.position - midPoint
      if halfID == 1 {
        delta = rotation.act(on: delta)
        
        let dotPart = (delta * axis).sum()
        delta -= 2 * dotPart * axis
      }
      
      atom.position = midPoint + delta
      actualAtoms.append(atom)
    }
  }
  
  for i in actualAtoms.indices {
    var atom = actualAtoms[i]
    atom.position -= midPoint
    atom.position = SIMD3(
      (atom.position * axisX).sum(),
      (atom.position * axisY).sum(),
      (atom.position * axisZ).sum())
    actualAtoms[i] = atom
  }
  
  // Add the hydrogens.
  
  var topology = Topology()
  topology.insert(atoms: actualAtoms)
  
  let matches = topology.match(topology.atoms)
  
  var insertedBonds: [SIMD2<UInt32>] = []
  for i in topology.atoms.indices {
    for j in matches[i] where i < j {
      insertedBonds.append(SIMD2(UInt32(i), UInt32(j)))
    }
  }
  topology.insert(bonds: insertedBonds)
  
  let orbitals = topology.nonbondingOrbitals()
  var insertedAtoms: [Entity] = []
  insertedBonds = []
  for i in topology.atoms.indices {
    let center = topology.atoms[i]
    guard case .atom(let element) = center.type else {
      fatalError()
    }
    let bondLength = element.covalentRadius + Element.hydrogen.covalentRadius
    for orbital in orbitals[i] {
      let position = center.position + bondLength * orbital
      let hydrogen = Entity(position: position, type: .atom(.hydrogen))
      let hydrogenID = topology.atoms.count + insertedAtoms.count
      let bond = SIMD2(UInt32(i), UInt32(hydrogenID))
      insertedAtoms.append(hydrogen)
      insertedBonds.append(bond)
    }
  }
  topology.insert(atoms: insertedAtoms)
  topology.insert(bonds: insertedBonds)
  
  return topology
}

