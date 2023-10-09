//
//  MM4Parameters+Torsions.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/7/23.
//

import Foundation

// MARK: - Functions for assigning per-torsion parameters.

/// Parameters for a group of 4 atoms.
public struct MM4Torsions {
  /// Each value corresponds to the torsion at the same array index.
  public var extendedParameters: [MM4TorsionExtendedParameters?] = []
  
  /// Groups of atom indices that form a torsion.
  public var indices: [SIMD4<Int32>] = []
  
  /// Map from a group of atoms to a torsion index.
  public var map: [SIMD4<Int32>: Int32] = [:]
  
  /// Each value corresponds to the torsion at the same array index.
  public var parameters: [MM4TorsionParameters] = []
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8] = []
}

/// Parameters for a torsion among carbon or hydrogen atoms, and
/// the first few terms of a fluorine torsion.
///
/// V1 term:
/// - zeroed out for X-C-C-H
/// - present for C-C-C-C
/// - present for 5-membered rings
/// - present for X-C-C-F
///
/// V3 term:
/// - present for X-C-C-H
/// - present for C-C-C-C
/// - present for 5-membered rings
/// - present for X-C-C-F
///
/// Vn term:
/// - 6 for some cases of X-C-C-H
/// - 2 for some cases of C-C-C-C
/// - zeroed out for 5-membered rings
/// - 2 for X-C-C-F
///
/// 1-term torsion-stretch:
/// - present for X-C-C-H
/// - present for C-C-C-C
/// - present for 5-membered rings
/// - zeroed out for X-C-C-F, to prioritize conciseness over performance
public struct MM4TorsionParameters {
  /// Units: kilocalorie / mole
  public var V1: Float
  
  /// Units: kilocalorie / mole
  public var Vn: Float
  
  /// Units: kilocalorie / mole
  public var V3: Float
  
  /// The factor to multiply the angle with inside the cosine term for Vn.
  ///
  /// The value of `n` is most often 2.
  public var n: Float
  
  /// Units: kilocalorie / angstrom \* mole^2
  public var Kts3: Float
}

/// Parameters for the various torsion forces unique to fluorine-containing
/// compounds (V4, V6, 3-term torsion-stretch, torsion-bend).
public struct MM4TorsionExtendedParameters {
  /// Units: kilocalorie / mole
  public var V4: Float
  
  /// Units: kilocalorie / mole
  public var V6: Float
  
  /// The V1-like term contributing to torsion-stretch stiffness.
  public var Kts1: (left: Float, central: Float, right: Float)
  
  /// The V2-like term contributing to torsion-stretch stiffness.
  public var Kts2: (left: Float, central: Float, right: Float)
  
  /// The V3-like term contributing to torsion-stretch stiffness.
  public var Kts3: (left: Float, central: Float, right: Float)
  
  /// The V1-like term contributing to torsion-bend stiffness.
  public var Ktb1: (left: Float, right: Float)
  
  /// The V2-like term contributing to torsion-bend stiffness.
  public var Ktb2: (left: Float, right: Float)
  
  /// The V3-like term contributing to torsion-bend stiffness.
  public var Ktb3: (left: Float, right: Float)
  
  /// Bend-torsion-bend constant.
  public var Kbtb: Float
}

extension MM4Parameters {
  func createTorsionParameters() {
    for torsionID in torsions.indices.indices {
      let torsion = torsions.indices[torsionID]
      let ringType = torsions.ringTypes[torsionID]
      
      var codes: SIMD4<UInt8> = .zero
      for lane in 0..<3 {
        let atomID = torsion[lane]
        codes[lane] = atoms.codes[Int(atomID)].rawValue
      }
      if any(codes .== 11 .| codes .== 19) {
        codes.replace(with: .init(repeating: 1), where: codes .== 123)
      }
      var sortedCodes = codes
      if codes[1] > codes[2] ||
          (codes[1] == codes[2] && codes[0] > codes[3]) {
        sortedCodes = SIMD4(codes[3], codes[2], codes[1], codes[0])
      }
      
      // This forcefield will not support Si-C-C-F torsions, for lack of torsion
      // parameters and secondary Electronegativity Effect parameters.
      if any(codes .== 11) && any(codes .== 19) {
        // There should be a similar fatal error for torsions.
        fatalError("Si-C-C-F torsions are not supported.")
      }
      
      var V1: Float = 0.000
      var Vn: Float = 0.000
      var V3: Float
      var n: Float = 2
      var V4: Float?
      var V6: Float?
      
      var Kts: Float
      var Kts_l: SIMD3<Float>?
      var Kts_c: SIMD3<Float>?
      var Kts_r: SIMD3<Float>?
      var Ktb_l: SIMD3<Float>?
      var Ktb_r: SIMD3<Float>?
      var Kbtb: Float?
      
      if any(sortedCodes .== 15) {
        Ktb_l = SIMD3(repeating: 0.000)
        Ktb_r = SIMD3(repeating: 0.000)
        Kbtb = 0.000
      }
      
      // There should be Swift unit tests to ensure generated torsion parameters
      // match the parameters from research papers, one test for every unique
      // parameter in the forcefield.
      switch (sortedCodes[0], sortedCodes[1], sortedCodes[2], sortedCodes[3]) {
        // Carbon
      case (1, 1, 1, 1):
        V1 = 0.239
        Vn = 0.024
        V3 = 0.637
      case (1, 1, 1, 5):
        V3 = 0.290
      case (5, 1, 1, 5), (5, 1, 123, 5):
        V3 = 0.260
        if sortedCodes[2] == 1 {
          Vn = 0.008
          n = 6
        }
      case (1, 123, 123, 1), (1, 123, 123, 123):
        V1 = 0.160
        V3 = 0.550
      case (5, 123, 123, 5):
        V3 = 0.300
      case (5, 123, 123, 123):
        V3 = 0.290
      case (123, 123, 123, 123):
        V1 = (ringType == 5) ? -0.150 : -0.120
        V3 = (ringType == 5) ? 0.160 : 0.550
      case (5, 1, 123, 123), (1, 123, 123, 5), (123, 1, 123, 5):
        V3 = 0.306
        
        // Fluorine
      case (1, 1, 1, 11):
        (V1, Vn, V3) = (-0.360, 0.380, 0.978)
        (V4, V6) = (0.240, 0.010)
        
        Kts_l = SIMD3(0.000, 0.000, 0.000)
        Kts_c = SIMD3(5.300, -4.800, 4.500)
        Kts_r = SIMD3(0.000, 0.000, 0.000)
        
        Ktb_l = SIMD3(0.000, -0.012, -0.009)
        Ktb_r = SIMD3(0.005, 0.004, 0.003)
        Kbtb = -0.06
      case (5, 1, 1, 11):
        (V1, Vn, V3) = (-0.460, 1.190, 0.420)
        (V4, V6) = (0.000, 0.000)
        
        Kts_l = SIMD3(0.000, 0.000, 0.000)
        Kts_c = SIMD3(0.000, -1.650, 2.400)
        Kts_r = SIMD3(0.000, 0.000, 0.550)
        
        Ktb_l = SIMD3(0.002, -0.022, 0.000)
        Ktb_r = SIMD3(0.000, 0.000, -0.001)
        Kbtb = 0.06
      case (11, 1, 1, 11):
        (V1, Vn, V3) = (-1.350, 0.305, 0.355)
        (V4, V6) = (0.000, 0.000)
        
        Kts_l = SIMD3(-5.550, 4.500, 0.000)
        Kts_c = SIMD3(4.800, -5.000, 1.559)
        Kts_r = SIMD3(-5.550, 4.500, 0.000)
        
        Ktb_l = SIMD3(0.000, -0.015, -0.003)
        Ktb_r = SIMD3(0.000, -0.015, -0.003)
        Kbtb = -0.06
        
        // Silicon
      case (1, 1, 1, 19):
        Vn = 0.050
        V3 = 0.240
        fatalError("TODO: Check the ab initio calculations for cyclosilanes.")
      case (19, 1, 1, 19), (1, 1, 19, 1), (19, 1, 19, 5):
        V3 = 0.167
      case (5, 1, 19, 1):
        V3 = 0.195
      case (5, 1, 19, 5):
        V3 = 0.177
      case (19, 1, 19, 1):
        V3 = 0.100
      case (1, 1, 19, 19):
        V3 = 0.300
      case (5, 1, 19, 19):
        V3 = 0.270
      case (1, 19, 19, 5):
        V3 = 0.127
      case (1, 19, 19, 1):
        V3 = 0.107
      case (1, 19, 19, 19):
        V3 = 0.350
      case (5, 19, 19, 5):
        V3 = 0.132
      case (5, 19, 19, 19):
        V3 = 0.070
      case (19, 19, 19, 19):
        V3 = (ringType == 5) ? 0.175 : 0.125
        
        // Sulfur
      case (5, 1, 15, 1):
        V3 = 0.540
        
        Ktb_l = SIMD3(0.012, 0.016, 0.000)
        Ktb_r = SIMD3(0.003, 0.000, 0.000)
        Kbtb = 0.135
      case (1, 1, 15, 1):
        V1 = 0.410
        V3 = 0.600
        
        Ktb_l = SIMD3(0.006, 0.020, 0.000)
        Kbtb = 0.080
      case (15, 1, 1, 15):
        V1 = 0.461
        Vn = 0.144
        V3 = 1.511
        
        Ktb_l = SIMD3(0.000, 0.003, 0.000)
        Kbtb = 0.130
      case (5, 1, 1, 15):
        V3 = 0.460
        Kbtb = 0.050
      case (1, 1, 1, 15):
        V1 = 0.420
        Vn = 0.100
        V6 = 0.200
        Kbtb = 0.090
      case (5, 123, 123, 5):
        V3 = 0.200
        Kbtb = 0.020
      case (123, 15, 123, 1), (123, 15, 123, 123):
        if ringType == 5 && all(sortedCodes .== SIMD4(123, 15, 123, 123)) {
          V1 = 0.440
          Vn = 0.300
          V3 = 0.500
        } else {
          V1 = 0.100
          V3 = 0.200
        }
      case (5, 1, 123, 15):
        Vn = 0.330
        V3 = 0.200
        Kbtb = 0.050
      case (15, 123, 123, 123):
        if ringType == 5 {
          V1 = 0.040
          Vn = 0.200
          V3 = 0.300
          Kbtb = 0.100
        } else {
          V1 = 0.520
          Vn = 0.080
          V3 = 0.250
          Kbtb = 0.100
        }
      case (123, 15, 123, 5):
        V3 = 0.450
        Kbtb = 0.020
      default:
        fatalError("Unrecognized torsion: \(sortedCodes[0]), \(sortedCodes[1]), \(sortedCodes[2]), \(sortedCodes[3])")
      }
      
      // MARK: - Off-diagonal cross-terms
      
      // The formula from the MM4 alkene paper was ambiguous, specifying "-k":
      //   -k * Δl * Kts * (1 + cos(3ω))
      // The formula from the MM3 original paper was:
      //    11.995 * (Kts/2) * (1 + cos(3ω))
      // After running several parameters through Desmos, and comparing similar
      // ones (https://www.desmos.com/calculator/p5wqbw7tku), I think I have
      // identified a typo. "-k" was supposed to be "K_s^-1" or "1/K_s". This
      // would result in:
      // - C-C having ~33% less TS stiffness in MM4 than in MM3
      // - C-Csp2 (MM4) having ~17% less stiffness than Si-Csp2 (MM3)
      // - C-S (MM4) having nearly identical stiffness to C-Si (MM3)
      // - Central TS for H-C-C-F (MM4) having 42% less peak stiffness than C-S
      // - Central TS for C-C-C-F (MM4) having 2x larger peaks than C-S, and a
      //   new trough with ~2x the magnitude of the C-S peak
      // - Central TS for F-C-C-F (MM4) having 1% less peak stiffness than C-S,
      //   but a new trough with ~3.7x the magnitude of the C-S peak
      
      var torsionCodes = codes
      if any(torsionCodes .== 11) || any(torsionCodes .== 19) {
        torsionCodes.replace(with: 1, where: torsionCodes .== 123)
      }
      if torsionCodes[1] > torsionCodes[2] ||
          (torsionCodes[1] == torsionCodes[2] &&
           torsionCodes[0] > torsionCodes[3]) {
        torsionCodes = SIMD4(
          torsionCodes[3], torsionCodes[2], torsionCodes[1], torsionCodes[0])
      }
      
      if any(torsionCodes .== 11) {
        precondition(
          torsionCodes[1] == 1 &&
          torsionCodes[2] == 1 &&
          torsionCodes[3] == 11,
          "Unrecognized fluorine torsion codes.")
        Kts = 0.000
        if codes[3] != 11 {
          swap(&Kts_l, &Kts_r)
          swap(&Ktb_l, &Ktb_r)
        }
      } else if any(torsionCodes .== 15) {
        // TODO: Torsion-stretch for sulfur.
      } else if torsionCodes[1] == 19 || torsionCodes[2] == 19 {
        // TODO: Torsion-stretch for silicon.
      }
    }
  }
}
