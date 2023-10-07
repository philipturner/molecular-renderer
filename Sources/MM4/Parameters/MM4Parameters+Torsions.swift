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
  /// Groups of atom indices that form a torsion.
  public var indices: [SIMD4<Int32>] = []
  
  /// Map from a group of atoms to a torsion index.
  public var map: [SIMD4<Int32>: Int32] = [:]
  
  /// Each value corresponds to the torsion at the same array index.
  public var heteroatomParameters: [MM4HeteroatomTorsionParameters?] = []
  
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
/// - zeroed out for X-C-C-F
public struct MM4TorsionParameters {
  /// Units: kilocalorie / mole
  public var V1: Float
  
  /// Units: kilocalorie / mole
  public var V3: Float
  
  /// Units: kilocalorie / mole
  public var Vn: Float
  
  /// The factor to multiply the angle with inside the cosine term for Vn.
  public var n: Float
  
  /// The V3-like term contributing to torsion-stretch stiffness.
  public var Kts3: Float
}

/// Parameters for the various torsion forces unique to fluorine-containing
/// compounds (V4, V6, 3-term torsion-stretch, torsion-bend).
public struct MM4HeteroatomTorsionParameters {
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
}
