//
//  MM4Parameters+Bonds.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/7/23.
//

import Foundation

// MARK: - Functions for assigning per-bond parameters.

/// Parameters for a group of 2 atoms.
public struct MM4Bonds {
  /// Each value corresponds to the bond at the same array index.
  public var extendedParameters: [MM4BondExtendedParameters?] = []
  
  /// Groups of atom indices that form a bond.
  public var indices: [SIMD2<Int32>] = []
  
  /// Map from a group of atoms to a bond index.
  public var map: [SIMD2<Int32>: Int32] = [:]
  
  /// Each value corresponds to the bond at the same array index.
  public var parameters: [MM4BondParameters] = []
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8] = []
}

/// Morse stretching parameters for a covalent bond. The bond's electric dipole
/// is also included in these parameters.
public struct MM4BondParameters {
  /// Units: millidyne \* angstrom
  ///
  /// The parameter's name originates from its description in
  /// Nanosystems 3.3.3(a).
  public var potentialWellDepth: Float
  
  /// Units: millidyne / angstrom
  public var stretchingStiffness: Float
  
  /// Units: angstrom
  public var equilibriumLength: Float
}

public struct MM4BondExtendedParameters {
  /// Units: debye
  public var dipoleMoment: Float
}

extension MM4Parameters {
  func createBondParameters() {
    for bondID in bonds.indices.indices {
      let bond = bonds.indices[bondID]
      let ringType = bonds.ringTypes[bondID]
      
      var codes: SIMD2<UInt8> = .zero
      for lane in 0..<2 {
        let atomID = bond[lane]
        codes[lane] = atoms.codes[Int(atomID)].rawValue
      }
      if any(codes .== 11 .| codes .== 19) {
        codes.replace(with: .init(repeating: 1), where: codes .== 123)
      }
      let minatomCode = codes.min()
      let maxatomCode = codes.max()
      let minAtomID = (codes[0] == minatomCode) ? bond[0] : bond[1]
      let maxAtomID = (codes[1] == maxatomCode) ? bond[1] : bond[0]
      
      var potentialWellDepth: Float
      var stretchingStiffness: Float
      var equilibriumLength: Float
      var dipoleMoment: Float?
      
      // There should be Swift unit tests to ensure generated bond parameters
      // match the parameters from research papers, one test for every unique
      // parameter in the forcefield.
      //
      // The tests should factor in Electronegativity Effect corrections.
      switch (minatomCode, maxatomCode) {
        // Carbon
      case (1, 1):
        potentialWellDepth = 1.130
        stretchingStiffness = 4.5500
        equilibriumLength = 1.5270
      case (1, 5):
        potentialWellDepth = 0.854
        equilibriumLength = 1.1120
        
        let centerType = atoms.centerTypes[Int(minAtomID)]
        switch centerType {
        case .tertiary:
          stretchingStiffness = 4.7400
        case .secondary:
          stretchingStiffness = 4.6700
        case .primary:
          stretchingStiffness = 4.7400
        default:
          fatalError("Unrecognized carbon type.")
        }
      case (5, 123):
        potentialWellDepth = 0.854
        equilibriumLength = 1.1120
        
        let centerType = atoms.centerTypes[Int(maxAtomID)]
        switch centerType {
        case .tertiary:
          stretchingStiffness = 4.7000
        case .secondary:
          stretchingStiffness = 4.6400
        default:
          fatalError("Unrecognized carbon type.")
        }
      case (1, 123):
        potentialWellDepth = 1.130
        stretchingStiffness = 4.5600
        equilibriumLength = 1.5270
      case (123, 123):
        potentialWellDepth = 1.130
        stretchingStiffness = (ringType == 5) ? 4.9900 : 4.5600
        equilibriumLength = (ringType == 5) ? 1.5290 : 1.5270
      
        // Fluorine
      case (1, 11):
        potentialWellDepth = 0.989
        stretchingStiffness = 6.10
        equilibriumLength = 1.3859
        dipoleMoment = (codes[1] == 11) ? +1.82 : -1.82
        
        // Silicon
      case (1, 19):
        potentialWellDepth = 0.812
        stretchingStiffness = (ringType == 5) ? 2.85 : 3.05
        equilibriumLength = (ringType == 5) ? 1.884 : 1.876
        
        var dipoleMagnitude: Float = (ringType == 5) ? 0.55 : 0.70
        dipoleMagnitude *= (codes[1] == 19) ? -1 : +1
        dipoleMoment = dipoleMagnitude
      case (5, 19):
        potentialWellDepth = 0.777
        stretchingStiffness = 2.65
        equilibriumLength = 1.483
      case (19, 19):
        potentialWellDepth = 0.672
        stretchingStiffness = 1.65
        equilibriumLength = (ringType == 5) ? 2.336 : 2.322
      default:
        fatalError("Not recognized: (\(minatomCode), \(maxatomCode))")
      }
      
      bonds.parameters.append(
        MM4BondParameters(
          potentialWellDepth: potentialWellDepth,
          stretchingStiffness: stretchingStiffness,
          equilibriumLength: equilibriumLength))
      
      if let dipoleMoment {
        bonds.extendedParameters.append(
          MM4BondExtendedParameters(dipoleMoment: dipoleMoment))
      } else {
        bonds.extendedParameters.append(nil)
      }
    }
  }
  
  // TODO: Create a counterforce at short range that corrects for 1/2 of a
  // dipole falling on the 1-3 border. In the paper about fluorine, Allinger
  // mentioned some 1-4 fluorines on fluoroethane having a repulsive effect
  // from their dipoles. This suggests 1-4 interactions ("sclfac = 1.000") are
  // included, but perhaps not the 1-3 interactions.
  func createPartialCharges() {
    // Units: proton charge * angstrom
    //
    // Dipole moment is positive if it points from a positive charge to a
    // negative charge. For example, a bond from C -> F should have a positive
    // dipole moment. A bond from F -> C should have a negative moment.
    let debye: Float = 0.2081943
    var charges = Array<Float>(repeating: 0, count: atoms.atomicNumbers.count)
    
    for (bondID, parameters) in bonds.extendedParameters.enumerated() {
      guard let parameters else { continue }
      let atomsMap = bondsToAtomsMap[bondID]
      let length = bonds.parameters[bondID].equilibriumLength
      let dipole = parameters.dipoleMoment
      
      // Dipole points from positive to negative (+->)
      let partialCharge = dipole * debye / length
      let atomCharges = SIMD2(+partialCharge, -partialCharge)
      for lane in 0..<2 {
        let atomID = atomsMap[lane]
        charges[Int(atomID)] += atomCharges[lane]
      }
    }
  }
  
  private func electrostaticEffect(sign: Float) -> [Float] {
    var primaryNeighbors: [[(correction: Float, decay: Float)]] = Array(
      repeating: [], count: bonds.indices.count)
    var secondaryNeighborsSum: [Float] = Array(
      repeating: 0, count: bonds.indices.count)
    var bohlmannEffectSum: [Float] = Array(
      repeating: 0, count: bonds.indices.count)
    
    func correction(
      atomID: Int32, endID: Int32, bondID: Int32
    ) -> (
      correction: Float, bohlmann: Float?, decay: Float, beta: Float
    )? {
      let otherID = other(atomID: endID, bondID: bondID)
      var codeActing = atoms.codes[Int(atomID)].rawValue
      var codeEnd = atoms.codes[Int(endID)].rawValue
      var codeOther = atoms.codes[Int(otherID)].rawValue
      codeActing = (codeActing == 123) ? 1 : codeActing
      codeEnd = (codeEnd == 123) ? 1 : codeEnd
      codeOther = (codeOther == 123) ? 1 : codeOther
      
      let bondCodes = (min(codeEnd, codeOther), max(codeEnd, codeOther))
      let presentCodes = SIMD3(codeActing, codeEnd, codeOther)
      if any(presentCodes .== 11) && any(presentCodes .== 19) {
        // Fail if there's no parameters for the electrostatic effect on a
        // particular bond (e.g. secondary effect of fluorine on silicon).
        fatalError(
          "No parameters for electronegativity correction between F and Si.")
      }
      
      switch (bondCodes.0, bondCodes.1, codeEnd, codeActing) {
        // Fluorine
      case (1, 1, 1, 11):
        var sum: Float = 0.00
        var decay: Float = 1.00
        var count: Int = 0
        let neighbors = atomsToAtomsMap[Int(endID)]
        for lane in 0..<4 where neighbors[lane] != -1 {
          let atomID = neighbors[lane]
          let otherElement = atoms.atomicNumbers[Int(atomID)]
          if otherElement == 6 {
            count += 1
            sum += decay
            decay *= 0.38
          }
        }
        precondition(
          count > 0, "Carbon with a C-C bond didn't have any carbon neighbors.")
        
        let units = sum / Float(count)
        return (-0.0193 * units, nil, 0.38, 0.05)
      case (1, 5, 1, 11):
        let bohlmannEffect: Float = 0.0011
        return (-0.0052, bohlmannEffect, 0.55, 0.30)
      case (1, 11, 1, 1):
        return (0.0127, nil, 0.62, 0.40)
      case (1, 11, 1, 11):
        let bohlmannEffect: Float = -0.0028
        return (-0.0268, bohlmannEffect, 0.33, 0.67)
        
        // Silicon
      case (1, 1, 1, 19):
        return (0.009, nil, 0.62, 0.40)
      case (5, 19, 19, 19):
        return (0.003, nil, 0.62, 0.40)
      case (19, 19, 19, 19):
        return (-0.002, nil, 0.62, 0.40)
      case (19, 19, 19, 5):
        return (0.004, nil, 0.62, 0.40)
      case (1, 19, 19, 19):
        return (0.009, nil, 0.62, 0.40)
      case (1, 19, 1, 19):
        return (-0.004, nil, 0.62, 0.40)
        
      default:
        return nil
      }
    }
    
    for atom0 in 0..<Int32(atoms.atomicNumbers.count) {
      let zeroLevelAtoms = atomsToAtomsMap[Int(atom0)]
      
      for lane in 0..<4 where zeroLevelAtoms[lane] != -1 {
        let atom1 = zeroLevelAtoms[lane]
        let primaryLevelAtoms = atomsToAtomsMap[Int(atom1)]
        let primaryLevelBonds = atomsToBondsMap[Int(atom1)]
        
        for lane in 0..<4 where primaryLevelAtoms[lane] != -1 {
          let atom2 = primaryLevelAtoms[lane]
          if atom0 == atom2 { continue }
          
          let bondID = primaryLevelBonds[lane]
          let corr = correction(atomID: atom0, endID: atom1, bondID: bondID)
          if let corr, corr.correction * sign > 0 {
            primaryNeighbors[Int(bondID)].append((corr.correction, corr.decay))
          }
          if let bohlmann = corr?.bohlmann {
            bohlmannEffectSum[Int(bondID)] += bohlmann
          }
          
          let secondaryLevelAtoms = atomsToAtomsMap[Int(atom2)]
          let secondaryLevelBonds = atomsToBondsMap[Int(atom2)]
          for lane in 0..<4 where secondaryLevelAtoms[lane] != -1 {
            let atom3 = secondaryLevelAtoms[lane]
            if atom1 == atom3 { continue }
            if atom0 == atom3 { fatalError("This should never happen.") }
            
            let bondID = secondaryLevelBonds[lane]
            let corr = correction(atomID: atom0, endID: atom2, bondID: bondID)
            if let corr, corr.correction * sign > 0 {
              secondaryNeighborsSum[Int(bondID)] += corr.correction * corr.beta
            }
          }
        }
      }
    }
    
    return bonds.indices.indices.map { bondID in
      var correction: Float = 0
      var neighbors = primaryNeighbors[bondID]
      neighbors.sort(by: { $0.correction.magnitude > $1.correction.magnitude })
      
      var decay: Float = 1
      for (neighborID, neighbor) in neighbors.enumerated() {
        if neighborID > 0 {
          decay *= neighbor.decay
        }
        correction += neighbor.correction * decay
      }
      correction += secondaryNeighborsSum[bondID]
      correction += bohlmannEffectSum[bondID]
      return correction
    }
  }
  
  func addElectrostaticCorrections() {
    let electronegativeCorrections = electrostaticEffect(sign: -1)
    let electropositiveCorrections = electrostaticEffect(sign: +1)
    for i in bonds.indices.indices {
      var correction: Float = 0
      correction += electronegativeCorrections[i]
      correction += electropositiveCorrections[i]
      bonds.parameters[i].equilibriumLength += correction
    }
  }
}
