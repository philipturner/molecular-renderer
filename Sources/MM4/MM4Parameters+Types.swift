//
//  MM4Parameters+Types.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/2/23.
//

import Foundation

/// Parameters for the van der Waals force on a specific atom, with an
/// alternative value for use in hydrogen interactions. This force does not
/// include electric forces, which are handled separately in a bond-bond based
/// dipole interaction.
public struct MM4NonbondedParameters {
  /// Units:  kilocalorie / mole
  ///
  /// "Heteroatom" includes carbon; the term was simply chosen as an antonym to
  /// hydrogen. Epsilons are computed using the geometric mean for heteroatoms,
  /// otherwise substitute directly with the hydrogen epsilon.
  public var epsilon: (heteroatom: Float, hydrogen: Float)
  
  /// Units: angstrom
  ///
  /// "Heteroatom" includes carbon; the term was simply chosen as an antonym to
  /// hydrogen. Radii are computed using the arithmetic sum for heteroatoms,
  /// otherwise substitute directly with the hydrogen radius.
  public var radius: (heteroatom: Float, hydrogen: Float)
}

/// A configuration for a set of force field parameters.
public class MM4ParametersDescriptor {
  /// Required. The number of protons in the atom's nucleus.
  public var atomicNumbers: [UInt8] = []
  
  /// Required. Pairs of atom indices representing (potentially multiple)
  /// covalent bonds.
  public var bonds: [SIMD2<UInt32>] = []
  
  /// Optional. The bond order for each covalent bond, which may be fractional.
  ///
  /// If not specified, all covalent bonds are treated as sigma bonds.
  public var bondOrders: [Float]?
  
  /// Required. The amount of mass (in amu) to redistribute from a substituent
  /// atom to each covalently bonded hydrogen.
  ///
  /// The default is 1 amu.
  public var hydrogenMassRepartitioning: Double = 1.0
  
  public init() {
    
  }
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
  ///
  /// For nonpolar bonds, this should be zero.
  public var dipoleMoment: Float
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

/// MM4 codes for an element or an atom in a specific functional group.
public enum MM4AtomType: UInt8, RawRepresentable {
  /// Carbon (sp3)
  case alkaneCarbon = 1
  
  /// Hydrogen
  case hydrogen = 5
  
  /// Fluorine
  case fluorine = 11
  
  /// Silicon
  case silicon = 19
  
  /// Carbon (sp3, 5-ring)
  case cyclopentaneCarbon = 123
}

/// The number of hydrogens surrounding the carbon or silicon.
///
/// Methane carbons are disallowed in the simulator, as they will be simulated
/// very inaccurately. The fluorine parameters struggle with the edge case of
/// carbon tetrafluoride, and HMR creates the nonphysical carbon-8 isotope. In
/// general, primary sp3 carbons are also discouraged, for the same reasons
/// that methane is prohibited.
public enum MM4CenterType {
  case heteroatom(UInt8)
  case primary
  case secondary
  case tertiary
  case quaternary
}
