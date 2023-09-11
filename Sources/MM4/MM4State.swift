//
//  MM4State.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/10/23.
//

import Foundation

/// A configuration for a frame of a simulation.
public class MM4StateDescriptor {
  /// Required. Whether to report the system's total kinetic and potential
  /// energy.
  ///
  /// The default is `false`.
  public var energy: Bool = false
  
  /// Required. Whether to report each atom's position.
  ///
  /// The default is `false`.
  public var positions: Bool = false
  
  /// Required. Whether to report each atom's velocity.
  ///
  /// The default is `false`.
  public var velocities: Bool = false
  
  public init() {
    
  }
}

/// A frame of a simulation.
public class MM4State {
  /// The system's total kinetic energy.
  public internal(set) var kineticEnergy: Double?
  
  /// The position (in nanometers) of each atom's nucleus.
  public internal(set) var positions: [SIMD3<Float>]?
  
  /// The system's total potential energy.
  public internal(set) var potentialEnergy: Double?
  
  /// The velocity (in nanometers per picosecond), of each atom at the start of
  /// the simulation.
  public internal(set) var velocities: [SIMD3<Float>]?
  
  internal init() {
    
  }
}
