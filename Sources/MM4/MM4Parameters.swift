//
//  MM4Parameters.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/10/23.
//

import Foundation

/// A set of force field parameters.
public class MM4Parameters {
  public internal(set) var atomTypes: [MM4AtomType]
  
  /// The mass of each atom after hydrogen mass repartitioning.
  public internal(set) var masses: [Float]
  
  /// Groups of atom indices that form an angle.
  public internal(set) var angles: [SIMD3<Int32>]
  
  /// Groups of atom indices that form a torsion.
  public internal(set) var torsions: [SIMD4<Int32>]
  
  /// Atom pairs to be excluded from vdW interactions.
  public internal(set) var nonbondedExceptions13: [SIMD2<Int32>]
  
  /// Atom pairs that have reduced vdW interactions.
  public internal(set) var nonbondedExceptions14: [SIMD2<Int32>]
  
  /// Each value corresponds to the bond at the same array index.
  public internal(set) var bondParameters: [MM4BondParameters]
  
  /// Each value corresponds to the angle at the same array index.
  public internal(set) var angleParameters: [MM4AngleParameters]
  
  /// Each value corresponds to the torsion at the same array index.
  public internal(set) var carbonTorsionParameters: [MM4CarbonTorsionParameters?]
  
  /// Each value corresponds to the torsion at the same array index.
  public internal(set) var fluorineTorsionParameters: [MM4FluorineTorsionParameters?]
  
  /// Each value corresponds to the atom at the same array index.
  public internal(set) var nonbondedParameters: [MM4NonbondedParameters]
  
  /// Create a set of parameters using the specified configuration.
  public init(descriptor: MM4ParametersDescriptor) {
    // Initialize all of the properties so you can call instance members during
    // the initializer.
    self.atomTypes = []
    self.masses = []
    self.angles = []
    self.torsions = []
    self.nonbondedExceptions13 = []
    self.nonbondedExceptions14 = []
    self.bondParameters = []
    self.angleParameters = []
    self.carbonTorsionParameters = []
    self.fluorineTorsionParameters = []
    self.nonbondedParameters = []
    
    // MARK: - Create Bond Topology
    
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
    atomTypes = descriptor.atomicNumbers.indices.map { atomID in
      let atomicNumber = descriptor.atomicNumbers[atomID]
      switch atomicNumber {
      case 1:
        return .hydrogen
      case 6:
        let ringType = ringTypes[atomID]
        if ringType == 6 {
          return .carbon_sp3
        } else if ringType == 5 {
          return .carbon_sp3_5ring
        } else {
          fatalError("Unsupported carbon ring type: \(ringType)")
        }
      case 9:
        return .fluorine
      default:
        fatalError("Atomic number \(atomicNumber) not recognized.")
      }
    }
    
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
    
    // MARK: - Assign Parameters
    
    // TODO: Add Electronegativity Effect and Bohlmann Band corrections.
    // Implement this as a separate function that modifies the generated values
    // for bond length and angles. Preferably in something that just outputs
    // the delta L and delta Theta. Then, you apply the force constant
    // derivation formula in this Swift file, and apply the deltas to the
    // equilibrium lengths/angles.
    
    let carbonTypes = createCarbonTypes(
      atomicNumbers: descriptor.atomicNumbers,
      bondsToAtomsMap: bondsToAtomsMap,
      atomsToBondsMap: atomsToBondsMap)
    
    bondParameters = createBondParameters(
      atomTypes: atomTypes,
      bondCount: descriptor.bonds.count,
      bondsToAtomsMap: bondsToAtomsMap,
      carbonTypes: carbonTypes)
    
    nonbondedParameters = createNonbondedParameters(
      atomicNumbers: descriptor.atomicNumbers,
      hydrogenMassRepartitioning: descriptor.hydrogenMassRepartitioning)
  }
}

