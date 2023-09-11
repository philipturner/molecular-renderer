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
  
  public init() {
    
  }
}

/// A set of force field parameters.
public class MM4Parameters {
  /// The mass of each atom after hydrogen mass repartitioning.
  public internal(set) var masses: [Float]
  
  /// Create a set of parameters using the specified configuration.
  public init(descriptor: MM4ParametersDescriptor) {
    if let bondOrders = descriptor.bondOrders {
      precondition(
        bondOrders.allSatisfy { $0 == 1 },
        "Only sigma bonds accepted for now.")
    }
    
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
    
    fatalError("Not implemented.")
  }
}
