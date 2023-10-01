//
//  MM4Parameters.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/10/23.
//

import Foundation

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

/// Morse-Lippincott stretching parameters for a covalent bond. Switches
/// between the Morse and Lippincott functions at the equilibrium radius.
public struct MM4BondParameters {
  
}

/// Parameters for an angle between two bonds, including bending stiffness
/// and multiplicative contribution to bend-bend stiffness.
public struct MM4AngleParameters {
  
}

/// Parameters for a torsion among carbon or hydrogen atoms, and
/// the first few terms of a fluorine torsion.
///
/// V1 term:
/// - zeroed out for X-C-C-H
/// - present for C-C-C-C
/// - present for 5-membered rings
/// - present for C-C-C-F
///
/// V3 term:
/// - present for X-C-C-H
/// - present for C-C-C-C
/// - present for 5-membered rings
/// - present for C-C-C-F
///
/// Vn term:
/// - 6 for some cases of X-C-C-H
/// - 2 for some cases of C-C-C-C
/// - zeroed out for 5-membered rings
/// - 2 for C-C-C-F
///
/// 1-term torsion-stretch:
/// - present for X-C-C-H
/// - present for C-C-C-C
/// - present for 5-membered rings
/// - zeroed out for C-C-C-F
public struct MM4CarbonTorsionParameters {
  
}

/// Parameters for the various torsion forces unique to fluorine-containing
/// compounds (V4, V6, 3-term torsion-stretch, torsion-bend).
public struct MM4FluorineTorsionParameters {
  
}

/// Parameters for the van der Waals force on a specific atom, with an
/// alternative value for use in hydrogen interactions. This force does not
/// include electric forces, which are handled separately in a bond-bond based
/// dipole interaction.
public struct MM4NonbondedParameters {
  
}

/// A set of force field parameters.
public class MM4Parameters {
  /// The mass of each atom after hydrogen mass repartitioning.
  public internal(set) var masses: [Float]
  
  /// Groups of atom indices that form an angle.
  public internal(set) var angles: [SIMD3<Int32>]
  
  /// Groups of atom indices that form a torsion.
  public internal(set) var torsions: [SIMD4<Int32>]
  
  /// Atom pairs to be excluded from vdW and electric interactions.
  public internal(set) var nonbondedExceptions13: [SIMD2<Int32>]
  
  /// Atom pairs to have reduce vdW and/or electric interactions.
  public internal(set) var nonbondedExceptions14: [SIMD2<Int32>]
  
  /// Create a set of parameters using the specified configuration.
  public init(descriptor: MM4ParametersDescriptor) {
    // Check the bond orders.
    if let bondOrders = descriptor.bondOrders {
      precondition(
        bondOrders.allSatisfy { $0 == 1 }, "Pi bonds not supported yet.")
    }
    
    // Compile the bonds into a map.
    var bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>> =
      .allocate(capacity: descriptor.bonds.count + 1)
    bondsToAtomsMap += 1
    bondsToAtomsMap[-1] = SIMD2(repeating: -1)
    defer { free(bondsToAtomsMap - 1) }
    
    var atomsToBondsMap: UnsafeMutablePointer<SIMD4<Int32>> =
      .allocate(capacity: descriptor.atomicNumbers.count + 1)
    atomsToBondsMap += 1
    atomsToBondsMap[-1] = SIMD4(repeating: -1)
    defer { free(atomsToBondsMap - 1) }
    
    for bondID in 0..<descriptor.bonds.count {
      var bond = descriptor.bonds[bondID]
      
      // Sort the indices in the bond, so the lower appears first.
      bond = SIMD2(bond.min(), bond.max())
      bondsToAtomsMap[bondID] = SIMD2(truncatingIfNeeded: bond)
    }
    for atomID in 0..<descriptor.atomicNumbers.count {
      atomsToBondsMap[atomID] = SIMD4(repeating: -1)
    }
    for bondID in 0..<descriptor.bonds.count {
      let bond = bondsToAtomsMap[bondID]
      for j in 0..<2 {
        let atomID = Int(bond[j])
        var map = atomsToBondsMap[atomID]
        var succeeded = false
        for k in 0..<4 {
          if map[k] == -1 {
            map[k] = Int32(bondID)
            succeeded = true
            break
          }
        }
        if !succeeded {
          fatalError("An atom had more than 4 bonds.")
        }
        atomsToBondsMap[atomID] = map
      }
    }
    
    @inline(__always)
    func other<T: FixedWidthInteger, U: FixedWidthInteger>(
      atomID: T, bondID: U
    ) -> Int32 {
      let bond = bondsToAtomsMap[Int(bondID)]
      return (bond[0] == atomID) ? bond[1] : bond[0]
    }
    
    // Assign masses using hydrogen mass repartitioning.
    masses = descriptor.atomicNumbers.map { atomicNumber in
      MM4MassParameters.global.mass(atomicNumber: atomicNumber)
    }
    for atomID in 0..<descriptor.atomicNumbers.count
    where descriptor.atomicNumbers[atomID] == 1 {
      masses[atomID] += Float(descriptor.hydrogenMassRepartitioning)
      
      let map = atomsToBondsMap[atomID]
      guard map[0] != -1, map[1] == -1, map[2] == -1, map[3] == -1 else {
        fatalError("Hydrogen did not have exactly 1 bond.")
      }
      let substituentID = Int(other(atomID: atomID, bondID: map[0]))
      masses[substituentID] -= Float(descriptor.hydrogenMassRepartitioning)
    }
    
    // Traverse the bond topology.
    var ringTypes: [UInt8] = []
    var anglesMap: [SIMD3<Int32>: Bool] = [:]
    var torsionsMap: [SIMD4<Int32>: Bool] = [:]
    for atom1 in 0..<Int32(descriptor.atomicNumbers.count) {
      let map1 = atomsToBondsMap[Int(atom1)]
      var ringType: UInt8 = 6
      defer { ringTypes.append(ringType) }
      
      for lane2 in 0..<4 where map1[lane2] != -1 {
        let atom2 = other(atomID: atom1, bondID: map1[lane2])
        let map2 = atomsToBondsMap[Int(atom2)]
        
        for lane3 in 0..<4 where map2[lane3] != -1 {
          let atom3 = other(atomID: atom2, bondID: map2[lane3])
          if atom1 == atom3 { continue }
          
          if atom1 < atom3 {
            anglesMap[SIMD3(atom1, atom2, atom3)] = true
          }
          let map3 = atomsToBondsMap[Int(atom3)]
          for lane4 in 0..<4 where map3[lane4] != -4 {
            let atom4 = other(atomID: atom3, bondID: map3[lane4])
            if atom2 == atom4 {
              continue
            } else if atom1 == atom4 {
              ringType = min(3, ringType)
              continue
            } else if atom1 < atom4 {
              torsionsMap[SIMD4(atom1, atom2, atom3, atom4)] = true
            }
            
            let map4 = atomsToBondsMap[Int(atom4)]
            @inline(__always)
            func iterate(lane5: Int) -> SIMD4<Int32> {
              let atom5 = other(atomID: atom4, bondID: map4[lane5])
              let map5 = atomsToBondsMap[Int(atom5)]
              var atoms6 = SIMD4<Int32>(repeating: -1)
              for lane6 in 0..<4 {
                atoms6[lane6] = other(atomID: atom5, bondID: map5[lane6])
              }
              
              var ringType = SIMD4<Int32>(repeating: 6)
              ringType.replace(
                with: .init(repeating: 5), where: atom1 .== atoms6)
              ringType.replace(
                with: .init(repeating: 4),
                where: .init(repeating: atom1 == atom5))
              return ringType
            }
            
            var mask1 = iterate(lane5: 0)
            let mask2 = iterate(lane5: 1)
            var mask3 = iterate(lane5: 2)
            let mask4 = iterate(lane5: 3)
            mask1.replace(with: mask2, where: mask2 .< mask1)
            mask3.replace(with: mask4, where: mask4 .< mask3)
            mask1.replace(with: mask3, where: mask1 .< mask3)
            ringType = min(ringType, UInt8(truncatingIfNeeded: mask1.min()))
          }
        }
      }
    }
    guard ringTypes.allSatisfy({ $0 >= 5 }) else {
      fatalError("3- and 4-member rings not supported yet.")
    }
    angles = anglesMap.keys.map { $0 }
    torsions = torsionsMap.keys.map { $0 }
    
    // Create nonbonded exceptions.
    var nonbondedExceptions13Map: [SIMD2<Int32>: Bool] = [:]
    var nonbondedExceptions14Map: [SIMD2<Int32>: Bool] = [:]
    for torsion in torsions {
      guard torsion[0] < torsion[3] else {
        fatalError("Torsions were not sorted.")
      }
      nonbondedExceptions14Map[SIMD2(torsion[0], torsion[3])] = true
    }
    for angle in angles {
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
