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

/// A set of force field parameters.
public class MM4Parameters {
  /// The mass of each atom after hydrogen mass repartitioning.
  public internal(set) var masses: [Float]
  
  /// Create a set of parameters using the specified configuration.
  public init(descriptor: MM4ParametersDescriptor) {
    // Check the bond orders.
    if let bondOrders = descriptor.bondOrders {
      precondition(
        bondOrders.allSatisfy { $0 == 1 },
        "Only sigma bonds accepted for now.")
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
      let bondID = Int(map[0])
      let bond = bondsToAtomsMap[bondID]
      guard any(bond .== Int32(truncatingIfNeeded: atomID)) else {
        fatalError("Bond did not contain hydrogen.")
      }
      let substituentID = (bond[0] != Int32(truncatingIfNeeded: atomID))
      ? Int(bond[0]) : Int(bond[1])
      
      masses[substituentID] -= Float(descriptor.hydrogenMassRepartitioning)
    }
  }
}
 
