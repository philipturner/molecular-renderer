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
  /// Groups of atom indices that form an angle.
  public var indices: [SIMD3<Int32>] = []
  
  /// Each value corresponds to the angle at the same array index.
  public var heteroatomParameters: [MM4HeteroatomAngleParameters?] = []
  
  /// Each value corresponds to the angle at the same array index.
  public var parameters: [MM4AngleParameters] = []
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8] = []
}

/// Parameters for an angle between two bonds, including bending stiffness
/// and multiplicative contribution to bend-bend stiffness.
public struct MM4AngleParameters {
  /// This is an off-diagonal term, so units are omitted for brevity.
  public var bendBendStiffness: Float
  
  /// Units: millidyne \* angstrom / radian^2
  public var bendingStiffness: Float
  
  /// Units: radian
  public var equilibriumAngle: Float
  
  /// This is an off-diagonal term, so units are omitted for brevity.
  public var stretchBendStiffness: Float
}

public struct MM4HeteroatomAngleParameters {
  /// Stiffness for type 2 stretch-bend forces, affecting bonds not directly
  /// involved in this angle.
  public var stretchBendStiffness: Float
  
  public var stretchStretchStiffness: Float
}

extension MM4Parameters {
  func createAngleParameters() {
    for angle in angles.indices {
      var codes: SIMD3<UInt8> = .zero
      var rings: SIMD2<UInt8> = .zero
      for lane in 0..<3 {
        let atomID = angle[lane]
        codes[lane] = atoms.codes[Int(atomID)].rawValue
        rings[lane] = atoms.ringTypes[Int(atomID)]
      }
      if any(codes .== 11 .| codes .== 19) {
        codes.replace(with: .init(repeating: 1), where: codes .== 123)
      }
      let minatomCode = SIMD2(codes[0], codes[2]).min()
      let medatomCode = codes[1]
      let maxatomCode = SIMD2(codes[0], codes[2]).max()
      let minAtomID = (codes[0] == minatomCode) ? angle[0] : angle[2]
      let medAtomID = angle[1]
      let maxAtomID = (codes[2] == maxatomCode) ? angle[2] : angle[0]
      let ringType = rings.max()
      
      var bendingStiffnesses: SIMD3<Float>
      var equilibriumAngles: SIMD3<Float>
      let baseCarbonAngles: SIMD3<Float> = SIMD3(108.900, 109.470, 110.800)
      
      switch (minatomCode, medatomCode, maxatomCode) {
        // Carbon
      case (1, 1, 1):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.400, 111.800)
      case (1, 1, 5):
        bendingStiffnesses = SIMD3(0.590, 0.560, 0.600)
        equilibriumAngles = baseCarbonAngles
      case (5, 1, 5):
        bendingStiffnesses = SIMD3(repeating: 0.540)
        equilibriumAngles = SIMD3(107.700, 107.800, 107.700)
      case (1, 1, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.500, 111.800)
      case (1, 123, 5):
        bendingStiffnesses = SIMD3(repeating: 0.560)
        equilibriumAngles = baseCarbonAngles
      case (5, 1, 123):
        bendingStiffnesses = SIMD3(repeating: 0.560)
        equilibriumAngles = baseCarbonAngles
      case (5, 123, 5):
        bendingStiffnesses = SIMD3(repeating: 0.620)
        equilibriumAngles = SIMD3(107.800, 107.800, 0.000)
      case (1, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.740)
        equilibriumAngles = SIMD3(109.500, 110.500, 111.800)
      case (5, 123, 123):
        bendingStiffnesses = SIMD3(repeating: 0.580)
        equilibriumAngles = baseCarbonAngles
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
          bendingStiffnesses = SIMD3(repeating: 0.250)
          equilibriumAngles = SIMD3(118.00, 110.80, 111.20)
        } else {
          bendingStiffnesses = SIMD3(repeating: 0.320)
          equilibriumAngles = SIMD3(repeating: 106.00)
        }
      default:
        fatalError("Not recognized: (\(minatomCode), \(medatomCode), \(maxatomCode))")
      }
      
      // Factors in both the center type and the other atoms in the angle.
      var angleType: Int
      do {
        var matchMask: SIMD3<UInt8> = .zero
        matchMask.replace(with: .one, where: codes .== 5)
        let numHydrogens = Int(matchMask.wrappedSum())
        
        let centerType = atoms.centerTypes[Int(medAtomID)]
        switch centerType {
        case .quaternary:
          angleType = 1 - numHydrogens
        case .tertiary:
          angleType = 2 - numHydrogens
        case .secondary:
          angleType = 3 - numHydrogens
        case .primary:
          angleType = 4 - numHydrogens
        default:
          fatalError("Unrecognized center type: \(centerType)")
        }
      }
      
      // Calculate bend-bend parameters using atomic number instead of MM4 type.
    }
  }
}
