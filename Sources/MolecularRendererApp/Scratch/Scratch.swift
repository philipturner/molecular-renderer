// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

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

let xtbOptimizedStructure0 = [
  Entity(position: SIMD3(-0.0023, -0.1214, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.0023,  0.1214,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3372, -0.1147, -0.1927), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3372, -0.1147,  0.1927), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.4473,  0.1971,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3389,  0.1189,  0.1921), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.1167,  0.1913,  0.1897), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3389,  0.1189, -0.1921), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.1167,  0.1913, -0.1897), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2290, -0.1918,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3372,  0.1147,  0.1927), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3372,  0.1147, -0.1927), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.4473, -0.1971, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3389, -0.1189, -0.1921), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.1167, -0.1913, -0.1897), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3389, -0.1189,  0.1921), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.1167, -0.1913,  0.1897), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.2290,  0.1918, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.4730, -0.1696, -0.2046), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2692, -0.1671, -0.3117), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2692, -0.1671,  0.3117), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4730, -0.1696,  0.2046), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.5886,  0.1569, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4548,  0.3438, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4096,  0.1687,  0.3118), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1070,  0.3369,  0.2064), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0441,  0.1389,  0.3063), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4096,  0.1687, -0.3118), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0441,  0.1389, -0.3063), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1070,  0.3369, -0.2064), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2280, -0.3397, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2692,  0.1671,  0.3117), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4730,  0.1696,  0.2046), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4730,  0.1696, -0.2046), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2692,  0.1671, -0.3117), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4548, -0.3438,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.5886, -0.1569,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4096, -0.1687, -0.3118), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0441, -0.1389, -0.3062), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1070, -0.3369, -0.2064), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4096, -0.1687,  0.3118), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1070, -0.3369,  0.2064), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0441, -0.1389,  0.3062), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2280,  0.3397,  0.0000), type: .atom(.hydrogen)),
]

let xtbOptimizedCharges0 = [
  Float( 0.08020400),
  Float( 0.08020222),
  Float( 0.26257514),
  Float( 0.26257517),
  Float( 0.25819780),
  Float( 0.17350671),
  Float( 0.26126670),
  Float( 0.17350666),
  Float( 0.26126662),
  Float( 0.18816286),
  Float( 0.26258314),
  Float( 0.26258318),
  Float( 0.25820153),
  Float( 0.17350355),
  Float( 0.26126207),
  Float( 0.17350349),
  Float( 0.26126199),
  Float( 0.18816535),
  Float(-0.13690903),
  Float(-0.15036348),
  Float(-0.15036350),
  Float(-0.13690897),
  Float(-0.14241420),
  Float(-0.14152068),
  Float(-0.12547884),
  Float(-0.15362466),
  Float(-0.18299816),
  Float(-0.12547876),
  Float(-0.18299812),
  Float(-0.15362469),
  Float(-0.13856563),
  Float(-0.15036333),
  Float(-0.13691782),
  Float(-0.13691777),
  Float(-0.15036335),
  Float(-0.14151368),
  Float(-0.14243504),
  Float(-0.12547161),
  Float(-0.18300450),
  Float(-0.15362421),
  Float(-0.12547153),
  Float(-0.15362424),
  Float(-0.18300446),
  Float(-0.13856790),
]

let xtbOptimizedStructure2 = [
  Entity(position: SIMD3( 0.0063, -0.1195,  0.0036), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.0063,  0.1195, -0.0036), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3299, -0.1181, -0.2034), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3128, -0.1180,  0.1801), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.4264,  0.1964,  0.0025), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2952,  0.1142,  0.1769), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.1117,  0.1664,  0.1515), type: .atom(.carbon)),
  Entity(position: SIMD3(-0.3388,  0.1162, -0.1991), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.1180,  0.1928, -0.1964), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2158, -0.2012, -0.0157), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3299,  0.1181,  0.2034), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3128,  0.1180, -0.1801), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.4264, -0.1964, -0.0025), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.2952, -0.1142, -0.1769), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.1117, -0.1664, -0.1515), type: .atom(.carbon)),
  Entity(position: SIMD3( 0.3388, -0.1162,  0.1991), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.1180, -0.1928,  0.1964), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.2158,  0.2012,  0.0157), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.4643, -0.1765, -0.2158), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2632, -0.1638, -0.3263), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2551, -0.1813,  0.2993), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4555, -0.1524,  0.1898), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.5651,  0.1518,  0.0226), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4391,  0.3429, -0.0003), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.3324,  0.1757,  0.3063), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1082,  0.2752,  0.1604), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0561,  0.1295,  0.2379), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4144,  0.1659, -0.3159), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0388,  0.1374, -0.3077), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1067,  0.3380, -0.2167), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2185, -0.3492, -0.0190), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2632,  0.1638,  0.3263), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4643,  0.1765,  0.2158), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4555,  0.1524, -0.1898), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2551,  0.1813, -0.2993), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4391, -0.3429,  0.0003), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.5651, -0.1518, -0.0226), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.3324, -0.1757, -0.3063), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0561, -0.1295, -0.2379), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1082, -0.2752, -0.1604), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4144, -0.1659,  0.3159), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1067, -0.3380,  0.2167), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0388, -0.1374,  0.3077), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2185,  0.3492,  0.0190), type: .atom(.hydrogen)),
]

let xtbOptimizedCharges2 = [
  Float( 0.19803400),
  Float( 0.19803847),
  Float( 0.27326565),
  Float( 0.25792582),
  Float( 0.26267843),
  Float( 0.27450013),
  Float(-0.28519676),
  Float( 0.18512960),
  Float( 0.27339450),
  Float( 0.19302813),
  Float( 0.27326456),
  Float( 0.25792519),
  Float( 0.26267879),
  Float( 0.27450142),
  Float(-0.28519648),
  Float( 0.18513005),
  Float( 0.27339502),
  Float( 0.19302674),
  Float(-0.13453787),
  Float(-0.14535532),
  Float(-0.14233421),
  Float(-0.15917625),
  Float(-0.15735610),
  Float(-0.13223827),
  Float(-0.12742036),
  Float(-0.02437928),
  Float(-0.03528950),
  Float(-0.12140086),
  Float(-0.18684049),
  Float(-0.13902643),
  Float(-0.12740819),
  Float(-0.14535410),
  Float(-0.13453706),
  Float(-0.15917567),
  Float(-0.14233294),
  Float(-0.13223776),
  Float(-0.15735657),
  Float(-0.12742182),
  Float(-0.03528986),
  Float(-0.02437869),
  Float(-0.12140076),
  Float(-0.13902662),
  Float(-0.18683998),
  Float(-0.12740831),
]

let xtbOptimizedStructure4 = [
  Entity(position: SIMD3( 0.0128, -0.1173, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.0128,  0.1173, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3036, -0.1206, -0.1919), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3036, -0.1206,  0.1919), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.4087,  0.1978, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2942,  0.1127,  0.1843), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.1118,  0.1677,  0.1571), type: .atom(.carbon)),
  Entity(position: SIMD3(-0.2942,  0.1127, -0.1843), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.1118,  0.1677, -0.1571), type: .atom(.carbon)),
  Entity(position: SIMD3(-0.2040, -0.2114, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3036,  0.1206,  0.1918), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3036,  0.1206, -0.1918), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.4087, -0.1977,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.2942, -0.1126, -0.1843), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.1118, -0.1677, -0.1571), type: .atom(.carbon)),
  Entity(position: SIMD3( 0.2942, -0.1126,  0.1843), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.1118, -0.1677,  0.1571), type: .atom(.carbon)),
  Entity(position: SIMD3( 0.2040,  0.2114,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.4443, -0.1611, -0.2065), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2415, -0.1759, -0.3135), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2415, -0.1759,  0.3135), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4443, -0.1611,  0.2065), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.5478,  0.1494,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4244,  0.3441, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.3328,  0.1742,  0.3134), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1100,  0.2766,  0.1641), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0526,  0.1330,  0.2420), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.3328,  0.1742, -0.3134), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0526,  0.1330, -0.2420), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1100,  0.2766, -0.1641), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2099, -0.3595, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2415,  0.1759,  0.3134), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4444,  0.1611,  0.2065), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4444,  0.1611, -0.2065), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2415,  0.1759, -0.3134), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4244, -0.3441,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.5478, -0.1494, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.3328, -0.1742, -0.3134), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0526, -0.1330, -0.2420), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1100, -0.2766, -0.1641), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.3328, -0.1742,  0.3134), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1100, -0.2766,  0.1641), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0526, -0.1330,  0.2420), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2099,  0.3595,  0.0000), type: .atom(.hydrogen)),
]

let xtbOptimizedCharges4 = [
  Float( 0.29242565),
  Float( 0.29244997),
  Float( 0.26886526),
  Float( 0.26886526),
  Float( 0.27160235),
  Float( 0.28535253),
  Float(-0.28195255),
  Float( 0.28535253),
  Float(-0.28195255),
  Float( 0.19690707),
  Float( 0.26886762),
  Float( 0.26886762),
  Float( 0.27155204),
  Float( 0.28533489),
  Float(-0.28194062),
  Float( 0.28533489),
  Float(-0.28194062),
  Float( 0.19692875),
  Float(-0.15566761),
  Float(-0.13911743),
  Float(-0.13911743),
  Float(-0.15566761),
  Float(-0.16878670),
  Float(-0.11815346),
  Float(-0.12179589),
  Float(-0.00848463),
  Float(-0.02670873),
  Float(-0.12179589),
  Float(-0.02670873),
  Float(-0.00848463),
  Float(-0.11492638),
  Float(-0.13920204),
  Float(-0.15563040),
  Float(-0.15563039),
  Float(-0.13920204),
  Float(-0.11815547),
  Float(-0.16877389),
  Float(-0.12178481),
  Float(-0.02671269),
  Float(-0.00846982),
  Float(-0.12178481),
  Float(-0.00846982),
  Float(-0.02671269),
  Float(-0.11497612),
]

let xtbOptimizedStructure6 = [
  Entity(position: SIMD3( 0.0024, -0.1160, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.0024,  0.1160,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2724, -0.1211, -0.1596), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2724, -0.1211,  0.1596), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.3923,  0.2052,  0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.2741,  0.1111,  0.1783), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.0954,  0.1780,  0.1559), type: .atom(.carbon)),
  Entity(position: SIMD3(-0.2741,  0.1111, -0.1783), type: .atom(.silicon)),
  Entity(position: SIMD3(-0.0954,  0.1780, -0.1559), type: .atom(.carbon)),
  Entity(position: SIMD3(-0.1807, -0.1752,  0.0000), type: .atom(.carbon)),
  Entity(position: SIMD3( 0.2724,  0.1211,  0.1596), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.2724,  0.1211, -0.1596), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.3923, -0.2052, -0.0000), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.2741, -0.1111, -0.1783), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.0954, -0.1780, -0.1559), type: .atom(.carbon)),
  Entity(position: SIMD3( 0.2741, -0.1111,  0.1783), type: .atom(.silicon)),
  Entity(position: SIMD3( 0.0954, -0.1780,  0.1559), type: .atom(.carbon)),
  Entity(position: SIMD3( 0.1807,  0.1752, -0.0000), type: .atom(.carbon)),
  Entity(position: SIMD3(-0.4104, -0.1730, -0.1517), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2136, -0.1959, -0.2724), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.2136, -0.1959,  0.2724), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4104, -0.1730,  0.1517), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.5336,  0.1634, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.4024,  0.3523,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.3155,  0.1526,  0.3146), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0977,  0.2870,  0.1579), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0361,  0.1485,  0.2425), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.3155,  0.1526, -0.3146), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0361,  0.1485, -0.2425), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.0977,  0.2870, -0.1579), type: .atom(.hydrogen)),
  Entity(position: SIMD3(-0.1812, -0.2846,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2136,  0.1959,  0.2724), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4104,  0.1730,  0.1517), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4104,  0.1730, -0.1517), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.2136,  0.1959, -0.2724), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.4024, -0.3523, -0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.5336, -0.1634,  0.0000), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.3155, -0.1526, -0.3146), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0361, -0.1485, -0.2425), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0977, -0.2870, -0.1579), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.3155, -0.1526,  0.3146), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0977, -0.2870,  0.1579), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.0361, -0.1485,  0.2425), type: .atom(.hydrogen)),
  Entity(position: SIMD3( 0.1812,  0.2846, -0.0000), type: .atom(.hydrogen)),
]

let xtbOptimizedCharges6 = [
  Float( 0.38554707),
  Float( 0.38554707),
  Float( 0.37072988),
  Float( 0.37072988),
  Float( 0.28054517),
  Float( 0.28744681),
  Float(-0.28636314),
  Float( 0.28744681),
  Float(-0.28636314),
  Float(-0.34650163),
  Float( 0.37072988),
  Float( 0.37072988),
  Float( 0.28054517),
  Float( 0.28744681),
  Float(-0.28636314),
  Float( 0.28744681),
  Float(-0.28636314),
  Float(-0.34650163),
  Float(-0.14872439),
  Float(-0.12535724),
  Float(-0.12535724),
  Float(-0.14872439),
  Float(-0.15333586),
  Float(-0.10819322),
  Float(-0.12614585),
  Float( 0.00571210),
  Float(-0.00665617),
  Float(-0.12614585),
  Float(-0.00665617),
  Float( 0.00571210),
  Float( 0.00065449),
  Float(-0.12535724),
  Float(-0.14872439),
  Float(-0.14872439),
  Float(-0.12535724),
  Float(-0.10819322),
  Float(-0.15333586),
  Float(-0.12614585),
  Float(-0.00665617),
  Float( 0.00571210),
  Float(-0.12614585),
  Float( 0.00571210),
  Float(-0.00665617),
  Float( 0.00065449),
]
