//
//  MM4Parameters+Angles.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/7/23.
//

import Foundation

// MARK: - Functions for assigning per-angle parameters.

/// Parameters for a group of 3 atoms.
public struct MM4Angles {
  /// Each value corresponds to the angle at the same array index.
  public var extendedParameters: [MM4AngleExtendedParameters?] = []
  
  /// Groups of atom indices that form an angle.
  public var indices: [SIMD3<Int32>] = []
  
  /// Map from a group of atoms to an angle index.
  public var map: [SIMD3<Int32>: Int32] = [:]
  
  /// Each value corresponds to the angle at the same array index.
  public var parameters: [MM4AngleParameters] = []
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8] = []
}

/// Parameters for an angle between two bonds, including bending stiffness
/// and multiplicative contribution to bend-bend stiffness.
public struct MM4AngleParameters {
  /// Units: millidyne^2 / radian^2
  public var bendBendStiffness: Float
  
  /// Units: millidyne \* angstrom / radian^2
  public var bendingStiffness: Float
  
  /// Units: radian
  public var equilibriumAngle: Float
  
  /// Units: millidyne / radian \* mole
  public var stretchBendStiffness: Float
}

public struct MM4AngleExtendedParameters {
  /// Stiffness for type 2 stretch-bend forces, affecting bonds not directly
  /// involved in this angle.
  public var stretchBendStiffness: Float
  
  public var stretchStretchStiffness: Float
}

extension MM4Parameters {
  func createAngleParameters() {
    for angleID in angles.indices.indices {
      let angle = angles.indices[angleID]
      let ringType = angles.ringTypes[angleID]
      
      var codes: SIMD3<UInt8> = .zero
      for lane in 0..<3 {
        let atomID = angle[lane]
        codes[lane] = atoms.codes[Int(atomID)].rawValue
      }
      if any(codes .== 11 .| codes .== 19) {
        codes.replace(with: .init(repeating: 1), where: codes .== 123)
      }
      let minatomCode = SIMD2(codes[0], codes[2]).min()
      let medatomCode = codes[1]
      let maxatomCode = SIMD2(codes[0], codes[2]).max()
      
      // This forcefield will not support Si-C-F angles, for lack of angle
      // parameters and primary Electronegativity Effect parameters.
      if any(codes .== 11) && any(codes .== 19) {
        fatalError("Si-C-F angles are not supported.")
      }
      
      var bendingStiffnesses: SIMD3<Float>
      var equilibriumAngles: SIMD3<Float>
      let commonCarbonAngles: SIMD3<Float> = SIMD3(108.900, 109.470, 110.800)
      
      // There should be Swift unit tests to ensure generated angle parameters
      // match the parameters from research papers, one test for every unique
      // parameter in the forcefield.
      switch (minatomCode, medatomCode, maxatomCode) {
        // Carbon
      case (1, 1, 1):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.400, 111.800)
      case (1, 1, 5):
        bendingStiffnesses = SIMD3(0.590, 0.560, 0.600)
        equilibriumAngles = commonCarbonAngles
      case (5, 1, 5):
        bendingStiffnesses = SIMD3(repeating: 0.540)
        equilibriumAngles = SIMD3(107.700, 107.800, 107.700)
      case (1, 1, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.500, 111.800)
      case (1, 123, 5):
        bendingStiffnesses = SIMD3(repeating: 0.560)
        equilibriumAngles = commonCarbonAngles
      case (5, 1, 123):
        bendingStiffnesses = SIMD3(repeating: 0.560)
        equilibriumAngles = commonCarbonAngles
      case (5, 123, 5):
        bendingStiffnesses = SIMD3(repeating: 0.620)
        equilibriumAngles = SIMD3(107.800, 107.800, 0.000)
      case (1, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.500, 111.800)
      case (5, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.580)
        equilibriumAngles = commonCarbonAngles
      case (123, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(108.300, 108.900, 109.000)
        
        // Fluorine
      case (1, 1, 11):
        bendingStiffnesses = SIMD3(repeating: 0.92)
        equilibriumAngles = SIMD3(106.90, 108.20, 109.30)
      case (5, 1, 11):
        bendingStiffnesses = SIMD3(0.82, 0.88, 0.98)
        equilibriumAngles = SIMD3(107.95, 107.90, 108.55)
      case (11, 1, 11):
        bendingStiffnesses = SIMD3(1.95, 2.05, 1.62)
        equilibriumAngles = SIMD3(104.30, 105.90, 108.08)
        
        // Silicon
      case (1, 1, 19):
        if ringType == 6 {
          bendingStiffnesses = SIMD3(repeating: 0.400)
          equilibriumAngles = SIMD3(109.00, 112.70, 111.50)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.550)
          equilibriumAngles = SIMD3(repeating: 107.20)
        }
      case (5, 1, 19):
        bendingStiffnesses = SIMD3(repeating: 0.540)
        equilibriumAngles = SIMD3(109.50, 110.00, 108.90)
      case (1, 19, 1):
        if ringType == 6 {
          bendingStiffnesses = SIMD3(repeating: 0.480)
          equilibriumAngles = SIMD3(109.50, 110.40, 109.20)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.650)
          equilibriumAngles = SIMD3(102.80, 103.80, 99.50)
        }
      case (19, 1, 19):
        bendingStiffnesses = SIMD3(repeating: 0.350)
        equilibriumAngles = SIMD3(109.50, 119.50, 117.00)
      case (1, 19, 5):
        bendingStiffnesses = SIMD3(repeating: 0.400)
        equilibriumAngles = SIMD3(109.30, 107.00, 110.00)
      case (5, 19, 5):
        bendingStiffnesses = SIMD3(repeating: 0.460)
        equilibriumAngles = SIMD3(106.50, 108.70, 109.50)
      case (1, 19, 19):
        bendingStiffnesses = SIMD3(repeating: 0.450)
        equilibriumAngles = SIMD3(repeating: 109.00)
      case (5, 19, 19):
        bendingStiffnesses = SIMD3(repeating: 0.350)
        equilibriumAngles = SIMD3(repeating: 109.40)
      case (19, 19, 19):
        if ringType == 6 {
          // Typo from the MM3 silicon paper and retained in the MM3(2000)
          // implementation donated to Tinker. Quaternary sp3 carbon has the
          // parameters 109.5-112.7-111.5, while sp3 silicon *should* have
          // something similar: 109.5-110.8-111.2. I think 118.00 was a typo
          // from the column four cells below: 19-22-22. Anything connected to
          // the other side of a cyclopropane carbon (60°) should have an angle
          // like 120°. This is not the first typo I have caught in one of
          // Allinger's research papers, see the note about the MM4 formula for
          // the Torsion-Stretch cross-term.
          //
          // The stiffness does match up. Extrapolating the ratios of 1-1-19 :
          // 19-19-19 and 1-19-1 : 19-19-19 from 5-membered ring variants, one
          // gets 0.233 and 0.236 respectively for 19-19-19. That is very close
          // to 0.25, so I don't think that was messed up.
          bendingStiffnesses = SIMD3(repeating: 0.250)
          equilibriumAngles = SIMD3(109.50, 110.80, 111.20)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.320)
          equilibriumAngles = SIMD3(repeating: 106.00)
        }
        
        // Sulfur
      case (5, 1, 15):
        bendingStiffnesses = SIMD3(repeating: 0.782)
        equilibriumAngles = SIMD3(108.9, 108.8, 105.8)
      case (1, 15, 1):
        bendingStiffnesses = SIMD3(0.920, .nan, .nan)
        equilibriumAngles = SIMD3(97.2, .nan, .nan)
      case (1, 1, 15):
        bendingStiffnesses = SIMD3(repeating: 0.975)
        equilibriumAngles = SIMD3(102.6, 105.7, 107.7)
      case (5, 123, 5):
        bendingStiffnesses = SIMD3(0.680, 0.680, .nan)
        equilibriumAngles = SIMD3(109.1, 107.5, .nan)
      case (1, 123, 15):
        bendingStiffnesses = SIMD3(repeating: 0.975)
        equilibriumAngles = SIMD3(102.6, 110.8, 107.7)
      case (123, 15, 123):
        bendingStiffnesses = SIMD3(0.920, .nan, .nan)
        equilibriumAngles = SIMD3(ringType == 5 ? 96.5 : 97.2, .nan, .nan)
      case (15, 123, 123):
        if ringType == 5 {
          bendingStiffnesses = SIMD3(repeating: 1.050)
          equilibriumAngles = SIMD3(108.0, 108.0, 108.5)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.975)
          equilibriumAngles = SIMD3(repeating: 106.2)
        }
      default:
        fatalError("Unrecognized angle: (\(minatomCode), \(medatomCode), \(maxatomCode))")
      }
      
      // Factors in both the center type and the other atoms in the angle.
      var angleType: Int
      if medatomCode == 15 {
        angleType = 0
      } else {
        var matchMask: SIMD3<UInt8> = .zero
        matchMask.replace(with: .one, where: codes .== 5)
        let numHydrogens = Int(matchMask.wrappedSum())
        
        guard let centerType = atoms.centerTypes[Int(angle[1])] else {
          fatalError("Angle did not occur at tetravalent atom.")
        }
        switch centerType {
        case .quaternary:
          angleType = 1 - numHydrogens
        case .tertiary:
          angleType = 2 - numHydrogens
        case .secondary:
          angleType = 3 - numHydrogens
        case .primary:
          angleType = 4 - numHydrogens
        }
      }
      
      // MARK: - Off-diagonal cross-terms
      
      var bendBendStiffness: Float
      var stretchBendStiffness: Float
      var stretchBendStiffness2: Float?
      var stretchStretchStiffness: Float?
      
      var angleCodes = codes
      angleCodes.replace(with: .one, where: angleCodes .== 123)
      if angleCodes[0] > angleCodes[2] {
        angleCodes = SIMD3(angleCodes[2], angleCodes[1], angleCodes[0])
      }
      
      if angleCodes[0] == 5 && angleCodes[2] == 5 {
        bendBendStiffness = 0.000
        stretchBendStiffness = 0.000
      } else if any(angleCodes .== 11) {
        precondition(angleCodes[2] == 11, "Unrecognized fluorine angle codes.")
        if angleCodes[0] == 1 {
          bendBendStiffness = -0.10
          stretchBendStiffness = 0.160
          stretchBendStiffness2 = 0.000
          stretchStretchStiffness = 0.22
        } else if angleCodes[0] == 5 {
          bendBendStiffness = 0.00
          stretchBendStiffness = 0.160
          stretchBendStiffness2 = 0.000
          stretchStretchStiffness = -0.45
        } else if angleCodes[0] == 11 {
          bendBendStiffness = 0.09
          stretchBendStiffness = 0.140
          stretchBendStiffness2 = 0.275
          stretchStretchStiffness = 1.00
        } else {
          fatalError("Unrecognized fluorine angle codes.")
        }
      } else if angleCodes[1] == 15 {
        bendBendStiffness = 0.000
        if all(angleCodes .== SIMD3(1, 15, 1)) {
          stretchBendStiffness = (ringType == 5) ? 0.280 : 0.150
        } else {
          fatalError("Unrecognized sulfur angle codes.")
        }
      } else if angleCodes[1] == 19 {
        if any(angleCodes .== 5) {
          bendBendStiffness = 0.24
          stretchBendStiffness = 0.10
        } else {
          bendBendStiffness = 0.30
          stretchBendStiffness = 0.06
        }
      } else if angleCodes[1] == 1 {
        // Assume the MM4 paper's parameters for H-C-C/C-C-C also apply to
        // H-C-Si/C-C-Si/Si-C-Si.
        if any(angleCodes .== 5) {
          bendBendStiffness = 0.350
          stretchBendStiffness = 0.100
        } else {
          bendBendStiffness = 0.204
          stretchBendStiffness = (ringType == 5) ? 0.180 : 0.140
        }
      } else {
        fatalError("Unrecognized atom codes for angle.")
      }
      
      angles.parameters.append(
        MM4AngleParameters(
          bendBendStiffness: bendBendStiffness,
          bendingStiffness: bendingStiffnesses[angleType - 1],
          equilibriumAngle: equilibriumAngles[angleType - 1],
          stretchBendStiffness: stretchBendStiffness))
      if any(angleCodes .== 11) {
        guard let stretchBendStiffness2,
              let stretchStretchStiffness else {
          fatalError("Fluorine angle did not have extended parameters.")
        }
        angles.extendedParameters.append(
          MM4AngleExtendedParameters(
            stretchBendStiffness: stretchBendStiffness2,
            stretchStretchStiffness: stretchStretchStiffness))
      } else {
        angles.extendedParameters.append(nil)
      }
    }
  }
  
  // TODO: Before simulating hydrofluorocarbon storage tape, you must add the
  // MM4 Electronegativity Effect corrections to bond angles from fluorine.
}
