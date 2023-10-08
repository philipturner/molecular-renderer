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
  /// Parameters for one atom.
  public internal(set) var atoms: MM4Atoms = MM4Atoms()
  
  /// Parameters for a group of 2 atoms.
  public internal(set) var bonds: MM4Bonds = MM4Bonds()
  
  /// Parameters for a group of 3 atoms.
  public internal(set) var angles: MM4Angles = MM4Angles()
  
  /// Parameters for a group of 4 atoms.
  public internal(set) var torsions: MM4Torsions = MM4Torsions()
  
  /// Parameters for a group of 5 atoms.
  public internal(set) var rings: MM4Rings = MM4Rings()
  
  /// The amount of mass (in amu) redistrbuted from a substituent atom to each
  /// covalently bonded hydrogen.
  var hydrogenMassRepartitioning: Float = -1
  
  /// Atom pairs to be excluded from vdW interactions.
  var nonbondedExceptions13: [SIMD2<Int32>] = []
  
  /// Atom pairs that have reduced vdW interactions.
  var nonbondedExceptions14: [SIMD2<Int32>] = []
  
  /// Map from atoms to bonds that can be efficiently traversed.
  var atomsToBondsMap: UnsafeMutablePointer<SIMD4<Int32>>
  
  /// Map from bonds to atoms that can be efficiently traversed.
  var bondsToAtomsMap: UnsafeMutablePointer<SIMD2<Int32>>
  
  /// Map from atoms to connected atoms that can be efficienty traversed.
  var atomsToAtomsMap: UnsafeMutablePointer<SIMD4<Int32>>
  
  /// Create a set of parameters using the specified configuration.
  public init(descriptor: MM4ParametersDescriptor) {
    // Check the bond orders.
    if let bondOrders = descriptor.bondOrders {
      precondition(
        bondOrders.allSatisfy { $0 == 1 }, "Pi bonds not supported yet.")
    }
    
    // Compile the bonds into a map.
    bondsToAtomsMap = .allocate(capacity: descriptor.bonds.count + 1)
    bondsToAtomsMap += 1
    bondsToAtomsMap[-1] = SIMD2(repeating: -1)
    for bondID in 0..<descriptor.bonds.count {
      var bond = descriptor.bonds[bondID]
      
      // Sort the indices in the bond, so the lower appears first.
      bond = SIMD2(bond.min(), bond.max())
      bondsToAtomsMap[bondID] = SIMD2(truncatingIfNeeded: bond)
      bonds.indices.append(SIMD2(truncatingIfNeeded: bond))
    }
    
    atoms.atomicNumbers = descriptor.atomicNumbers
    atomsToBondsMap = .allocate(capacity: atoms.atomicNumbers.count + 1)
    atomsToBondsMap += 1
    atomsToBondsMap[-1] = SIMD4(repeating: -1)
    for atomID in 0..<atoms.atomicNumbers.count {
      atomsToBondsMap[atomID] = SIMD4(repeating: -1)
    }
    
    for bondID in 0..<bonds.indices.count {
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
    
    atomsToAtomsMap = .allocate(capacity: atoms.atomicNumbers.count + 1)
    atomsToAtomsMap += 1
    atomsToAtomsMap[-1] = SIMD4(repeating: -1)
    for atomID in 0..<atoms.atomicNumbers.count {
      let bondsMap = atomsToBondsMap[atomID]
      var atomsMap = SIMD4<Int32>(repeating: -1)
      for lane in 0..<4 {
        atomsMap[lane] = other(atomID: atomID, bondID: bondsMap[lane])
      }
      atomsToAtomsMap[atomID] = atomsMap
    }
    
    // Topology
    createTopology()
    createAtomCodes()
    createCenterTypes()
    
    // Per-Atom Parameters
    hydrogenMassRepartitioning = Float(descriptor.hydrogenMassRepartitioning)
    createMasses()
    createNonbondedParameters()
    createNonbondedExceptions()
    
    // Per-Bond Parameters
    createBondParameters()
    addElectrostaticCorrections()
    createPartialCharges()
  }
  
  deinit {
    (atomsToBondsMap - 1).deallocate()
    (bondsToAtomsMap - 1).deallocate()
    (atomsToAtomsMap - 1).deallocate()
  }
  
  @inline(__always)
  func other<T: FixedWidthInteger, U: FixedWidthInteger>(
    atomID: T, bondID: U
  ) -> Int32 {
    let bond = bondsToAtomsMap[Int(bondID)]
    return (bond[0] == atomID) ? bond[1] : bond[0]
  }
}
