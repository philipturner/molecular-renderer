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
      
      let chLengthInNm: Double = 3.440 * OpenMM_NmPerAngstrom
      let chEpsilonInKJ: Double = 0.024 * OpenMM_KJPerKcal
      nonbond.addGlobalParameter(name: "dispersionFactor", defaultValue: 1)
      nonbond.addGlobalParameter(name: "length_ch", defaultValue: chLengthInNm)
      nonbond.addGlobalParameter(name: "epsilon_ch", defaultValue: chEpsilonInKJ)
      
      // NOTE: This force handles both the CC/HH and CH cases.
      nonbond14 = OpenMM_CustomBondForce(energy: energy)
      nonbond14.addGlobalParameter(
        name: "dispersionFactor", defaultValue: 0.550)
      nonbond14.addPerBondParameter(name: "length")
      nonbond14.addPerBondParameter(name: "epsilon")
    }
    nonbond.transfer()
    system.addForce(nonbond)
    
    var nonbondParameters: [UInt8: OpenMM_DoubleArray] = [:]
    do {
      let hydrogenParameters = OpenMM_DoubleArray(size: 2)
      hydrogenParameters[0] = 1.640 * OpenMM_NmPerAngstrom
      hydrogenParameters[1] = 0.017 * OpenMM_KJPerKcal
      nonbondParameters[1] = hydrogenParameters
      
      let carbonParameters = OpenMM_DoubleArray(size: 2)
      carbonParameters[0] = 1.960 * OpenMM_NmPerAngstrom
      carbonParameters[1] = 0.037 * OpenMM_KJPerKcal
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
    
    // Don't include bend-bend and bend-stretch terms yet.
    let bondStretch = OpenMM_HarmonicBondForce()
    let bondBend = OpenMM_HarmonicAngleForce()
    let bondTorsion = OpenMM_PeriodicTorsionForce()
    bondStretch.transfer()
    bondBend.transfer()
    bondTorsion.transfer()
    system.addForce(bondStretch)
    system.addForce(bondBend)
    system.addForce(bondTorsion)
  }
}
