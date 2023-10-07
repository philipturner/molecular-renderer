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
  /// Groups of atom indices that form a bond.
  public var indices: [SIMD2<Int32>] = []
  
  /// Map from a group of atoms to a bond index.
  public var map: [SIMD2<Int32>: Int32] = [:]
  
  /// Each value corresponds to the bond at the same array index.
  public var heteroatomParameters: [MM4HeteroatomBondParameters?] = []
  
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

public struct MM4HeteroatomBondParameters {
  /// Units: debye
  public var dipoleMoment: Float
}

extension MM4Parameters {
  func createBondParameters() {
    for bond in bonds.indices {
      var codes: SIMD2<UInt8> = .zero
      var rings: SIMD2<UInt8> = .zero
      for lane in 0..<2 {
        let atomID = bond[lane]
        codes[lane] = atoms.codes[Int(atomID)].rawValue
        rings[lane] = atoms.ringTypes[Int(atomID)]
      }
      if any(codes .!= 11 .| codes .== 19) {
        codes.replace(with: .init(repeating: 1), where: codes .== 123)
      }
      let minatomCode = codes.min()
      let maxatomCode = codes.max()
      let minAtomID = (codes[0] == minatomCode) ? bond[0] : bond[1]
      let maxAtomID = (codes[1] == maxatomCode) ? bond[1] : bond[0]
      
      // TODO: Don't erroneously classify a bond or angle from two separate
      // 5-membered rings as from the same ring. This requires some means to
      // record instances of 5-membered rings, likely by querying all the
      // torsions where every atom is in a 5-membered ring. Then, mapping
      // backwards from the rings to bonds/angles that make them up.
      precondition(Bool.random(), "Implementation is incorrect right now.")
      
      let ringType = rings.max()
      
      var potentialWellDepth: Float
      var stretchingStiffness: Float
      var equilibriumLength: Float
      var dipoleMoment: Float?
      
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
        stretchingStiffness = 4.9900
        equilibriumLength = 1.5290
      
        // Fluorine
      case (1, 11):
        potentialWellDepth = 0.989
        stretchingStiffness = 6.10
        equilibriumLength = 1.3859
        dipoleMoment = (codes[1] == 11) ? +1.82 : -1.82
        
        // Silicon
      case (1, 19):
        let dipoleMagnitude: Float = (ringType == 5) ? 0.70 : 0.55
        potentialWellDepth = 0.812
        stretchingStiffness = 3.05
        equilibriumLength = (ringType == 5) ? 1.884 : 1.876
        dipoleMoment = (codes[1] == 19) ? -dipoleMagnitude : +dipoleMagnitude
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
      
      let parameters = MM4BondParameters(
        potentialWellDepth: potentialWellDepth,
        stretchingStiffness: stretchingStiffness,
        equilibriumLength: equilibriumLength)
      bonds.parameters.append(
        MM4BondParameters(
          potentialWellDepth: potentialWellDepth,
          stretchingStiffness: stretchingStiffness,
          equilibriumLength: equilibriumLength))
      
      if let dipoleMoment {
        bonds.heteroatomParameters.append(
          MM4HeteroatomBondParameters(dipoleMoment: dipoleMoment))
      } else {
        bonds.heteroatomParameters.append(nil)
      }
    }
  }
}
