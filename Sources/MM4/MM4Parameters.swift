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
  
  // TODO: Support ionic charges.
  
  public init() {
    
  }
}

/// A set of force field parameters.
public class MM4Parameters {
  /// The mass of each atom after hydrogen mass repartitioning.
  public internal(set) var masses: [Float]
  
  // TODO: Stiffness of each bonded force term.
  
  /// Create a set of parameters using the specified configuration.
  public init(descriptor: MM4ParametersDescriptor) {
    fatalError("Not implemented.")
  }
}
