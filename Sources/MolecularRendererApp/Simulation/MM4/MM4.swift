//
//  MM4.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/29/23.
//

import Foundation
import MolecularRenderer
import OpenMM
import simd

// "An improved force field (MM4) for saturated hydrocarbons"
// - 1996
// - Norman L. Allinger, Kuohsiang Chen, Jenn-Huei Lii
// https://doi.org/10.1002/(SICI)1096-987X(199604)17:5/6%3C642::AID-JCC6%3E3.0.CO;2-U
//
// "Molecular mechanics (MM4) study of saturated four-membered ring hydrocarbons"
// - 2002
// - Kuo-Hsiang Chen, Norman L Allinger
// - https://doi.org/10.1016/S0166-1280(01)00760-6
//
// "Molecular Mechanics (MM4) Studies on Unusually Long Carbon–Carbon Bond Distances in Hydrocarbons"
// - 2016
// - Norman L. Allinger, Jenn-Huei Lii, and Henry F. Schaefer, III
// - https://pubs.acs.org/doi/10.1021/acs.jctc.5b00926
//
// https://github.com/TinkerTools/tinker/blob/b6a58df90c5a66eceab92cc821d12b4dd27ca096/params/mm3.prm

class MM4 {
  var system: OpenMM_System
  
  init(atoms: [MRAtom], bonds: [SIMD2<Int32>], stepSizeInFs: Double) {
    self.system = OpenMM_System()
    
    var nonbond: OpenMM_CustomNonbondedForce
    var nonbond14: OpenMM_CustomBondForce
    do {
      let energy = """
        dispersionFactor * epsilon * (
          -2.25 * (length / r)^6 +
          1.84e5 * exp(-12.00 * (r / length))
        );
        """
      nonbond = OpenMM_CustomNonbondedForce(energy: energy + """
        length = select(is_ch, length_ch, radius1 + radius2);
        epsilon = select(is_ch, epsilon_ch, sqrt(epsilon1 * epsilon2));
        is_ch = (min(element1, element2) == 1) && (max(element1, element2) == 6);
        """)
      nonbond.addPerParticleParameter(name: "radius")
      nonbond.addPerParticleParameter(name: "epsilon")
      nonbond.addPerParticleParameter(name: "element")
      
      let chLengthInNm: Double = 3.440 * OpenMM_NmPerAngstrom
      let chEpsilonInKJ: Double = 0.024 * OpenMM_KJPerKcal
      nonbond.addGlobalParameter(name: "dispersionFactor", defaultValue: 1)
      nonbond.addGlobalParameter(name: "length_ch", defaultValue: chLengthInNm)
      nonbond.addGlobalParameter(
        name: "epsilon_ch", defaultValue: chEpsilonInKJ)
      
      nonbond14 = OpenMM_CustomBondForce(energy: energy)
      nonbond14.addGlobalParameter(
        name: "dispersionFactor", defaultValue: 0.550)
      nonbond14.addPerBondParameter(name: "length")
      nonbond14.addPerBondParameter(name: "epsilon")
    }
    nonbond.transfer()
    nonbond14.transfer()
    system.addForce(nonbond)
    system.addForce(nonbond14)
    
    var nonbondParameters: [UInt8: OpenMM_DoubleArray] = [:]
    do {
      let hydrogenParameters = OpenMM_DoubleArray(size: 3)
      hydrogenParameters[0] = 1.640 * OpenMM_NmPerAngstrom
      hydrogenParameters[1] = 0.017 * OpenMM_KJPerKcal
      hydrogenParameters[2] = 1
      nonbondParameters[1] = hydrogenParameters
      
      let carbonParameters = OpenMM_DoubleArray(size: 3)
      carbonParameters[0] = 1.960 * OpenMM_NmPerAngstrom
      carbonParameters[1] = 0.037 * OpenMM_KJPerKcal
      carbonParameters[2] = 6
      nonbondParameters[6] = carbonParameters
    }
    
    for atom in atoms {
      switch atom.element {
      case 1:
        system.addParticle(mass: 1.008)
      case 6:
        // Don't give any special treatment to cyclobutane and cyclopentane
        // carbons. Instead, replace the cubane test with adamantane.
        system.addParticle(mass: 12.011)
        break
      default:
        fatalError("Unsupported element: \(atom.element)")
      }
      
      nonbond.addParticle(parameters: nonbondParameters[atom.element]!)
    }
    
    let bondPairs = OpenMM_BondArray(size: bonds.count)
    var atomsToBondsMap: [SIMD4<Int32>] = Array(
      repeating: SIMD4(repeating: -1), count: atoms.count)
    for (bondIndex, bond) in bonds.enumerated() {
      bondPairs[bondIndex] = SIMD2(truncatingIfNeeded: bond)
      for i in 0..<2 {
        let atomIndex = Int(bond[i])
        var previous = atomsToBondsMap[atomIndex]
        for i in 0..<5 {
          if i == 4 {
            fatalError("More than four bonds on an atom.")
          }
          if previous[i] == -1 {
            previous[i] = Int32(truncatingIfNeeded: bondIndex)
            break
          }
        }
        atomsToBondsMap[atomIndex] = previous
      }
    }
    nonbond.createExclusionsFromBonds(bondPairs, bondCutoff: 3)
    
    var bonds13: [SIMD2<Int32>: Bool] = [:]
    var bonds123: [SIMD3<Int32>: Bool] = [:]
    var bonds14: [SIMD2<Int32>: Bool] = [:]
    var bonds1234: [SIMD4<Int32>: Bool] = [:]
    func traverse(
      stack: inout SIMD4<Int32>,
      currentID: Int32,
      recursionLevel: Int
    ) {
      let bondMap = atomsToBondsMap[Int(currentID)]
      for i in 0..<4 {
        let bondIndex = Int(bondMap[i])
        guard bondIndex > -1 else {
          break
        }
        let bond = bonds[bondIndex]
        
        var partnerID: Int32
        if bond[0] == currentID {
          partnerID = bond[1]
        } else if bond[1] == currentID {
          partnerID = bond[0]
        } else {
          fatalError("Bond did not contain this atom index.")
        }
        if partnerID <= stack[recursionLevel - 1] {
          continue
        }
        stack[recursionLevel] = partnerID
        
        let newBond = SIMD2(stack[0], partnerID)
        if recursionLevel == 2 {
          let newAngle = SIMD3(stack[0], stack[1], stack[2])
          bonds13[newBond] = true
          bonds123[newAngle] = true
        } else if recursionLevel == 3 {
          bonds14[newBond] = true
          bonds1234[stack] = true
        }
        if recursionLevel < 3 {
          traverse(
            stack: &stack, currentID: partnerID,
            recursionLevel: recursionLevel + 1)
        }
      }
    }
    
    for atomID in atoms.indices {
      var stack = SIMD4<Int32>(Int32(atomID), -1, -1, -1)
      traverse(stack: &stack, currentID: Int32(atomID), recursionLevel: 1)
    }
    for bond12 in bonds {
      bonds13[bond12] = nil
      bonds14[bond12] = nil
    }
    for bond13 in bonds13.keys {
      bonds14[bond13] = nil
    }
    
    do {
      var bondParameters: [SIMD2<UInt8>: OpenMM_DoubleArray] = [:]
      
      let hhParameters = OpenMM_DoubleArray(size: 2)
      hhParameters[0] = 2 * 1.640 * OpenMM_NmPerAngstrom
      hhParameters[1] = 0.017 * OpenMM_KJPerKcal
      bondParameters[[1, 1]] = hhParameters
      
      let chParameters = OpenMM_DoubleArray(size: 2)
      chParameters[0] = 3.440 * OpenMM_NmPerAngstrom
      chParameters[1] = 0.024 * OpenMM_KJPerKcal
      bondParameters[[1, 6]] = chParameters
      
      let ccParameters = OpenMM_DoubleArray(size: 2)
      ccParameters[0] = 2 * 1.960 * OpenMM_NmPerAngstrom
      ccParameters[1] = 0.037 * OpenMM_KJPerKcal
      bondParameters[[6, 6]] = ccParameters
      
      for bond in bonds14.keys {
        let atom1 = atoms[Int(bond[0])]
        let atom2 = atoms[Int(bond[1])]
        let element1 = min(atom1.element, atom2.element)
        let element2 = max(atom1.element, atom2.element)
        
        let parameters = bondParameters[SIMD2(element1, element2)]!
        nonbond14.addBond(
          particles: SIMD2(truncatingIfNeeded: bond), parameters: parameters)
      }
    }
    
    var bondStretch: OpenMM_CustomBondForce
    // bondBend
    // bondTorsion
    // bondBendBend
    // bondStretchBend
    
    do {
      let energy = """
        0.5 * stiffness * delta_l^2 * (1
          - scale
          + (7.0 / 12) * scale^2
          - fifth_power_term * scale^3
          + sixth_power_term * scale^4
        );
        scale = cubic_stretch * delta_l;
        delta_l = r - length;
        """
      bondStretch = OpenMM_CustomBondForce(energy: energy)
      bondStretch.addPerBondParameter(name: "stiffness")
      bondStretch.addPerBondParameter(name: "length")
      bondStretch.addPerBondParameter(name: "cubic_stretch")
      bondStretch.addPerBondParameter(name: "fifth_power_term")
      bondStretch.addPerBondParameter(name: "sixth_power_term")
      
      var bondParameters: [SIMD2<UInt8>: OpenMM_DoubleArray] = [:]
      let kjPerMolPerAJ: Double = 1e-18 / (1000 / 6.022e23)
      
      let chParameters = OpenMM_DoubleArray(size: 5)
      chParameters[0] = 474 * kjPerMolPerAJ
      chParameters[1] = 1.1120 * OpenMM_NmPerAngstrom
      chParameters[2] = 2.20
      chParameters[3] = 1.0 / 4
      chParameters[4] = 31.0 / 360
      bondParameters[[1, 6]] = chParameters
      
      let ccParameters = OpenMM_DoubleArray(size: 5)
      ccParameters[0] = 455 * kjPerMolPerAJ
      ccParameters[1] = 1.5270 * OpenMM_NmPerAngstrom
      ccParameters[2] = 3.00
      ccParameters[3] = 0.03
      ccParameters[4] = 0.17
      bondParameters[[6, 6]] = ccParameters
      
      for bond in bonds {
        let atom1 = atoms[Int(bond[0])]
        let atom2 = atoms[Int(bond[1])]
        let element1 = min(atom1.element, atom2.element)
        let element2 = max(atom1.element, atom2.element)
        
        let parameters = bondParameters[SIMD2(element1, element2)]!
        bondStretch.addBond(
          particles: SIMD2(truncatingIfNeeded: bond), parameters: parameters)
      }
    }
    do {
      
    }
    do {
      
    }
    do {
      
    }
    do {
      
    }
    
    bondStretch.transfer()
//    bondBend.transfer()
//    bondTorsion.transfer()
//    bondBendBend.transfer()
//    bondStretchBend.transfer()
    system.addForce(bondStretch)
//    system.addForce(bondBend)
//    system.addForce(bondTorsion)
//    system.addForce(bondBendBend)
//    system.addForce(bondStretchBend)
  }
}
