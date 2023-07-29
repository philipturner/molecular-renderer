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
    var chNonbond: OpenMM_CustomNonbondedForce
    do {
      let energy = """
        epsilon * (
          -2.25 * (length / r)^6 +
          1.84e5 * exp(-12.00 * (r / length))
        );
        """
      nonbond = OpenMM_CustomNonbondedForce(energy: energy + """
        length = radius1 + radius2;
        epsilon = sqrt(epsilon1 * epsilon2);
        """)
      nonbond.addPerParticleParameter(name: "radius")
      nonbond.addPerParticleParameter(name: "epsilon")
      
      let chLengthInNm: Double = 3.440 * OpenMM_NmPerAngstrom
      let chEpsilonInKJ: Double = 0.024 * OpenMM_KJPerKcal
      chNonbond = OpenMM_CustomNonbondedForce(energy: energy)
      nonbond.addGlobalParameter(name: "length", defaultValue: chLengthInNm)
      nonbond.addGlobalParameter(name: "epsilon", defaultValue: chEpsilonInKJ)
    }
    nonbond.transfer()
    chNonbond.transfer()
    system.addForce(nonbond)
    system.addForce(chNonbond)
    
    for atom in atoms {
      switch atom.element {
      case 1:
        break
      case 6:
        // Don't give any special treatment to cyclobutane and cyclopentane
        // carbons yet.
        break
      default:
        fatalError("Unsupported element: \(atom.element)")
      }
      
      guard atom.element == 6 || atom.element == 1 else {
        fatalError("Unsupported element: \(atom.element)")
      }
      
      if atom.element == 1 {
        
      } else {
        
      }
    }
    
    // TODO: Add exclusions for C-H bonds to the first nonbonded force.
    // TODO: Use interaction groups for the second nonbonded force.
    // TODO: Add 1-3 exclusions to both nonbonded forces.
    
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
