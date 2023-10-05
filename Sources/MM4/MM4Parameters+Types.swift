//
//  MM4Parameters+Types.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/2/23.
//

import Foundation

/// Parameters for one atom.
public struct MM4Atoms {
  /// The number of protons in the atom's nucleus.
  public var atomicNumbers: [UInt8]
  
  /// The center type used to assign different parameters.
  ///
  /// This is useful for debugging the assignment of parameters, to ensure the
  /// exact parameter as specified by the forcefield paper gets assigned.
  public var centerTypes: [MM4CenterType]
  
  /// The MM4 code for each atom in the system.
  public var codes: [MM4AtomCode]
  
  /// The mass of each atom after hydrogen mass repartitioning.
  public var masses: [Float]
  
  /// Each value corresponds to the atom at the same array index.
  public var nonbondedParameters: [MM4NonbondedParameters]
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8]
}

/// Parameters for a group of 2 atoms.
public struct MM4Bonds {
  /// Groups of atom indices that form a bond.
  public var indices: [SIMD2<Int32>]
  
  /// Each value corresponds to the bond at the same array index.
  public var heteroatomParameters: [MM4HeteroatomBondParameters?]
  
  /// Each value corresponds to the bond at the same array index.
  public var parameters: [MM4BondParameters]
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8]
}

/// Parameters for a group of 3 atoms.
public struct MM4Angles {
  /// Groups of atom indices that form an angle.
  public var indices: [SIMD3<Int32>]
  
  /// Each value corresponds to the angle at the same array index.
  public var heteroatomParameters: [MM4HeteroatomAngleParameters?]
  
  /// Each value corresponds to the angle at the same array index.
  public var parameters: [MM4AngleParameters]
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8]
}

/// Parameters for a group of 4 atoms.
public struct MM4Torsions {
  /// Groups of atom indices that form a torsion.
  public var indices: [SIMD4<Int32>]
  
  /// Each value corresponds to the torsion at the same array index.
  public var heteroatomParameters: [MM4HeteroatomTorsionParameters?]
  
  /// Each value corresponds to the torsion at the same array index.
  public var parameters: [MM4TorsionParameters]
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8]
}

/// Parameters for a group of 5 atoms.
///
/// The forcefield parameters may be slightly inaccurate for rings with mixed
/// carbon and silicon atoms (not sure). In the future, this may be expanded to
/// 3-atom and 4-atom rings.
public struct MM4Rings {
  /// Groups of atom indices that form a ring.
  public var indices: [SIMD8<Int32>]
  
  /// The number of atoms in the ring.
  public var ringTypes: [UInt8]
}

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
public enum MM4AtomCode: UInt8, RawRepresentable {
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
