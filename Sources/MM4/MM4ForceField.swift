//
//  MM4ForceField.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/10/23.
//

import Foundation

/// A configuration for a force field simulator.
public class MM4ForceFieldDescriptor {
  /// Optional. The force (in piconewtons) exerted on each atom.
  public var externalForces: [SIMD3<Float>]?
  
  /// Required. The largest time step (in picoseconds) that may be taken during
  /// a simulation.
  ///
  /// The default is approximately 4 femtoseconds.
  public var maximumTimeStep: Double = 0.100 / 23 + 1e-8
  
  /// Required. The set of parameters defining the forcefield.
  public var parameters: MM4Parameters?
  
  /// Required. The position (in nanometers) of each atom's nucleus.
  public var positions: [SIMD3<Float>] = []
  
  /// Required. The one-to-one mapping of atom indices to rigid bodies.
  public var rigidBodies: [[UInt32]] = []
  
  /// Optional. Whether each atom's absolute position should never change.
  public var stationaryAtoms: [Bool]?
  
  /// Required. The temperature (in Kelvin) to initialize thermal velocities at.
  ///
  /// The default is 25 degrees Celsius.
  public var temperature: Double = 298.15
  
  /// Optional. The velocity (in nanometers per picosecond), of each atom at the
  /// start of the simulation.
  ///
  /// These are added to thermal velocities in a way that conserves each rigid
  /// body's overall momentum.
  public var velocities: [SIMD3<Float>]?
  
  public init() {
    
  }
}

/// A force field simulator.
public class MM4ForceField {
  /// Create a simulator using the specified configuration.
  public init(descriptor: MM4ForceFieldDescriptor) {
    MM4Plugins.global.load()
    
    // Separate the atoms into two groups of "small" vs "large" atoms, creating
    // different zones of internally contiguous tiles within the atom list.
  }
  
  /// Simulate the system's evolution for the specified time interval (in
  /// picoseconds).
  public func simulate(time: Double) {
    // If the time doesn't divide evenly into 100 fs, compile a temporary
    // integrator that executes the remainder, potentially with a slightly
    // scaled-down timestep.
  }
  
  /// Retrieve a frame of the simulation.
  public func state(descriptor: MM4StateDescriptor) -> MM4State {
    if descriptor.positions {
      // Add the positions flag to the OpenMM state data type.
    }
    if descriptor.velocities {
      // Add the velocities flag to the OpenMM state data type.
    }
    if descriptor.energy {
      // Add the energy flag to the OpenMM state data type.
    }
    
    let state = MM4State()
    if descriptor.positions {
      // Set the positions.
    }
    if descriptor.velocities {
      // Set the velocities.
    }
    if descriptor.energy {
      // Set the kinetic and potential energy.
    }
    return state
  }
}
