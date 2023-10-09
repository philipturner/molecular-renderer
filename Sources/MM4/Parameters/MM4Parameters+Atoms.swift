//
//  MM4Parameters+Atoms.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/7/23.
//

import Foundation

// MARK: - Functions for assigning per-atom parameters.

/// Parameters for one atom.
public struct MM4Atoms {
  /// The number of protons in the atom's nucleus.
  public var atomicNumbers: [UInt8] = []
  
  /// The center type used to assign different parameters.
  ///
  /// This is useful for debugging the assignment of parameters, to ensure the
  /// exact parameter as specified by the forcefield paper gets assigned.
  public var centerTypes: [MM4CenterType?] = []
  
  /// The MM4 code for each atom in the system.
  public var codes: [MM4AtomCode] = []
  
  /// Each value corresponds to the atom at the same array index.
  public var extendedParameters: [MM4AtomExtendedParameters?] = []
  
  /// The mass of each atom after hydrogen mass repartitioning.
  public var masses: [Float] = []
  
  /// Each value corresponds to the atom at the same array index.
  public var nonbondedParameters: [MM4NonbondedParameters] = []
  
  /// The smallest ring this is involved in.
  public var ringTypes: [UInt8] = []
}

/// MM4 codes for an element or an atom in a specific functional group.
public enum MM4AtomCode: UInt8, RawRepresentable {
  /// Carbon (sp3)
  case alkaneCarbon = 1
  
  /// Hydrogen
  case hydrogen = 5
  
  /// Fluorine
  case fluorine = 11
  
  /// Sulfur
  case sulfur = 15
  
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
public enum MM4CenterType: UInt8 {
  case primary = 1
  case secondary = 2
  case tertiary = 3
  case quaternary = 4
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

public struct MM4AtomExtendedParameters {
  /// Partial charge in units of proton charge.
  public var charge: Float
}

extension MM4Parameters {
  func createMasses() {
    atoms.masses = atoms.atomicNumbers.map { atomicNumber in
      MM4MassParameters.global.mass(atomicNumber: atomicNumber)
    }
    for atomID in 0..<atoms.atomicNumbers.count
    where atoms.atomicNumbers[atomID] == 1 {
      atoms.masses[atomID] += hydrogenMassRepartitioning
      
      // HMR affects both carbon and silicon.
      let map = atomsToBondsMap[atomID]
      guard map[0] != -1, map[1] == -1, map[2] == -1, map[3] == -1 else {
        fatalError("Hydrogen did not have exactly 1 bond.")
      }
      let substituentID = Int(other(atomID: atomID, bondID: map[0]))
      atoms.masses[substituentID] -= hydrogenMassRepartitioning
    }
  }
  
  func createAtomCodes() {
    atoms.codes = atoms.atomicNumbers.indices.map { atomID in
      let atomicNumber = atoms.atomicNumbers[atomID]
      switch atomicNumber {
      case 1:
        let map = atomsToAtomsMap[atomID]
        for lane in 0..<4 where map[lane] != -1 {
          if atoms.atomicNumbers[Int(lane)] == 16 {
            fatalError("Thiol hydrogen not allowed.")
          }
        }
        return .hydrogen
      case 6:
        let ringType = atoms.ringTypes[atomID]
        switch ringType {
        case 6:
          return .alkaneCarbon
        case 5:
          return .cyclopentaneCarbon
        default:
          fatalError("Unsupported carbon ring type: \(ringType)")
        }
      case 9:
        return .fluorine
      case 14:
        return .silicon
      default:
        fatalError("Atomic number \(atomicNumber) not recognized.")
      }
    }
  }
  
  func createCenterTypes() {
    for atomID in atoms.atomicNumbers.indices {
      let atomicNumber = atoms.atomicNumbers[atomID]
      guard atomicNumber == 6 || atomicNumber == 14 else {
        precondition(
          atomicNumber == 1 || atomicNumber == 9,
          "Atomic number \(atomicNumber) not recognized.")
        atoms.centerTypes.append(nil)
        continue
      }
      
      let map = atomsToAtomsMap[atomID]
      guard all(map .> -1) else {
        fatalError("A carbon did not have 4 valid bonds.")
      }
      var otherElements: SIMD4<UInt8> = .zero
      for lane in 0..<4 {
        let otherID = map[lane]
        otherElements[lane] = atoms.atomicNumbers[Int(otherID)]
      }
      
      // In MM4, fluorine is treated like carbon when determining carbon types.
      // Allinger notes this may be a weakness of the forcefield.
      var matchMask: SIMD4<UInt8> = .zero
      matchMask.replace(with: .one, where: otherElements .== 9)
      matchMask.replace(with: .one, where: otherElements .== 14)
      
      var carbonType: MM4CenterType
      switch matchMask.wrappedSum() {
      case 4:
        carbonType = .quaternary
      case 3:
        carbonType = .tertiary
      case 2:
        carbonType = .secondary
      case 1:
        carbonType = .primary
      default:
        fatalError("This should never happen.")
      }
      atoms.centerTypes.append(carbonType)
    }
  }
  
  // Two forces:
  // - Short-range vdW force between pairs of non-charged atoms smaller than
  //   the C-Si vdW radius.
  //   - Interaction group 1: small vdW radius and non-charged
  //   - Interaction group 2: any vdW radius and any charge status
  // - Electrostatics and either (a) larger vdW radii or (b) vdW interactions
  //   between pairs of charged particles.
  //   - Interaction group 1: large vdW radius and/or charged
  //   - Interaction group 2: large vdW radius and/or charged
  //
  // Near-term unoptimized alternative: two separate O(n^2) forces without any
  // cutoff, one for vdW and one for electrostatics
  func createNonbondedParameters() {
    for atomID in atoms.atomicNumbers.indices {
      let atomicNumber = atoms.atomicNumbers[atomID]
      var epsilon: (heteroatom: Float, hydrogen: Float)
      var radius: (heteroatom: Float, hydrogen: Float)
      
      switch atomicNumber {
      case 1:
        epsilon = (heteroatom: 0.017, hydrogen: 0.017)
        radius = (heteroatom: 1.640, hydrogen: 1.640)
      case 6:
        let t = Float(hydrogenMassRepartitioning) - 0
        let hydrogenRadius = t * (3.410 - 3.440) + 3.440
        epsilon = (heteroatom: 0.037, hydrogen: 0.024)
        radius = (heteroatom: 1.960, hydrogen: hydrogenRadius)
      case 9:
        // Change vdW force to emulate polarization of a nearby C-H bond.
        epsilon = (heteroatom: 0.075, hydrogen: 0.092 * pow(1 / 0.9, 6))
        radius = (heteroatom: 1.710, hydrogen: 2.870 * 0.9)
      case 14:
        // Scale silicon-hydrogen vdW parameters by 0.94, as suggested for MM4.
        epsilon = (heteroatom: 0.140, hydrogen: 0.046)
        radius = (heteroatom: 2.290, hydrogen: 3.690)
      case 16:
        epsilon = (heteroatom: 0.196, hydrogen: 0.0577 * pow(1 / 0.94, 6))
        radius = (heteroatom: 2.090, hydrogen: 3.730 * 0.94)
      default:
        fatalError("Atomic number \(atomicNumber) not recognized.")
      }
      atoms.nonbondedParameters.append(
        MM4NonbondedParameters(epsilon: epsilon, radius: radius))
    }
  }
  
  func createNonbondedExceptions() {
    // Create nonbonded exceptions.
    var nonbondedExceptions13Map: [SIMD2<Int32>: Bool] = [:]
    var nonbondedExceptions14Map: [SIMD2<Int32>: Bool] = [:]
    for torsion in torsions.indices {
      guard torsion[0] < torsion[3] else {
        fatalError("Torsions were not sorted.")
      }
      nonbondedExceptions14Map[SIMD2(torsion[0], torsion[3])] = true
    }
    for angle in angles.indices {
      guard angle[0] < angle[2] else {
        fatalError("Angle was not sorted.")
      }
      nonbondedExceptions13Map[SIMD2(angle[0], angle[2])] = true
      nonbondedExceptions14Map[SIMD2(angle[0], angle[2])] = nil
    }
    nonbondedExceptions13 = nonbondedExceptions13Map.keys.map { $0 }
    nonbondedExceptions14 = nonbondedExceptions14Map.keys.map { $0 }
  }
}
