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
  
  /// Required. The amount of mass (in amu) to redistribute from a substituent
  /// atom to each covalently bonded hydrogen.
  ///
  /// The default is 1 amu.
  public var hydrogenMassRepartitioning: Double = 1.0
  
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
  
  // TODO: Support a thermostat that dissipates energy into stationary atoms.
  //
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
    // Create the following forces from the paramters:
    // - van der Waals (Buckingham)
    // - electrostatic
    //   - only if any polar covalent bonds exist
    // - bond stretch (Morse)
    // - bond bend (sextic) + stretch-bend
    // - bond bend-bend
    // - bond torsion + torsion-stretch
    //   - excludes torsions with torsion-bend and bend-torsion-bend terms
    // - bond torsion-bend + bend-torsion-bend
    //   - computes torsion + torsion-stretch for included torsions
  }
}

/// A force field simulator.
public class MM4ForceField {
  /// Create a simulator using the specified configuration.
  public init(descriptor: MM4ForceFieldDescriptor) {
    
  }
  
  /// Adjust the atom positions to be in the lowest-energy state.
  ///
  /// Typically, this is called when the bulk of the crystolecule is set to be
  /// stationary. It ignores the system's temperature and produces the
  /// lowest-energy structure at 0 Kelvin. It also ignores the maximum time step
  /// and uses a stepping scheme that minimizes numerical instability.
  public func minimize() {
    // Lazily create the following forces:
    // - van der Waals (Lennard-Jones 4-2)
    // - van der Waals (Lennard-Jones 12-6)
    // - bond stretch (harmonic)
    // - bond bend (harmonic)
    // - bond bend (quartic)
  }
  
  /// Simulate the system's evolution for the specified time interval (in
  /// picoseconds).
  public func simulate(time: Double) {
    
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
