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

// Elements to port (in order of easiness):
//
// Chlorine:
// https://onlinelibrary.wiley.com/doi/epdf/10.1002/%28SICI%291099-1395%28199701%2910%3A1%3C3%3A%3AAID-POC851%3E3.0.CO%3B2-A
//
// Silicon:
// https://onlinelibrary.wiley.com/doi/pdf/10.1002/(SICI)1099-1395(199709)10:9%3C697::AID-POC905%3E3.0.CO;2-3
//
// Nitrogen:
// https://onlinelibrary.wiley.com/doi/full/10.1002/jcc.20737
//
// Eventually, sp2 carbon, which requires more changes than the other elements.

fileprivate let kjPerMolPerAJ: Double = 1e-18 / (1000 / 6.022e23)

class MM4 {
  var system: OpenMM_System
  var integrator: OpenMM_Integrator
  var context: OpenMM_Context
  var provider: OpenMM_AtomProvider
  
  convenience init(diamondoid: Diamondoid) {
    self.init(atoms: diamondoid.atoms, bonds: diamondoid.bonds)
  }
  
  // 1.2 ps/s for now. Eventually, drive that up to 12 ps/s.
  init(atoms: [MRAtom], bonds: [SIMD2<Int32>], fsPerFrame: Int = 2) {
    self.system = OpenMM_System()
    
    var nonbond: OpenMM_CustomNonbondedForce
    var nonbond14: OpenMM_CustomBondForce
    do {
      let energy = """
        epsilon * (
          -2.25 * (length / r)^6 +
          1.84e5 * exp(-12.00 * (r / length))
        );
        """
      nonbond = OpenMM_CustomNonbondedForce(energy: energy + """
        length = select(is_ch, length_ch, radius1 + radius2);
        epsilon = select(is_ch, epsilon_ch, sqrt(epsilon1 * epsilon2));
        is_ch = is_min_h * is_max_c;
        is_min_h = select(min_element - 1, 0, 1);
        is_max_c = select(max_element - 1, 0, 1);
        min_element = min(element1, element2);
        max_element = max(element1, element2);
        """)
      nonbond.addPerParticleParameter(name: "radius")
      nonbond.addPerParticleParameter(name: "epsilon")
      nonbond.addPerParticleParameter(name: "element")
      
      let chLengthInNm: Double = 3.440 * OpenMM_NmPerAngstrom
      let chEpsilonInKJ: Double = 0.024 * OpenMM_KJPerKcal
      nonbond.addGlobalParameter(name: "length_ch", defaultValue: chLengthInNm)
      nonbond.addGlobalParameter(
        name: "epsilon_ch", defaultValue: chEpsilonInKJ)
      
      nonbond14 = OpenMM_CustomBondForce(energy: "0.550 * " + energy)
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
        // carbons. Instead, restrict designs to only those based on a diamond
        // lattice.
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
    
    func getNot(id: Int32, from list: SIMD2<Int32>) -> Int32 {
      var output: Int32
      if list[0] == id {
        output = list[1]
      } else if list[1] == id {
        output = list[0]
      } else {
        fatalError("Bond did not contain this atom index.")
      }
      precondition(output != id)
      return output
    }
    
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
        
        let partnerID = getNot(id: currentID, from: bond)
        precondition(partnerID != currentID)
        if any(stack .== partnerID) {
          continue
        }
        
        stack[recursionLevel] = partnerID
        if stack[0] < partnerID {
          let newBond = SIMD2(stack[0], partnerID)
          if recursionLevel == 2 {
            precondition(stack[0] != -1)
            precondition(stack[1] != -1)
            precondition(stack[2] != -1)
            precondition(stack[3] == -1)
            
            let newAngle = SIMD3(stack[0], stack[1], stack[2])
            precondition(bonds123[newAngle] == nil)
            bonds13[newBond] = true
            bonds123[newAngle] = true
          } else if recursionLevel == 3 {
            precondition(stack[0] != -1)
            precondition(stack[1] != -1)
            precondition(stack[2] != -1)
            precondition(stack[3] != -1)
            
            precondition(bonds1234[stack] == nil)
            bonds14[newBond] = true
            bonds1234[stack] = true
          }
        }
        if recursionLevel < 3 {
          traverse(
            stack: &stack, currentID: partnerID,
            recursionLevel: recursionLevel + 1)
        }
        stack[recursionLevel] = -1
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
    
    var stretchParameters: [SIMD2<UInt8>: OpenMM_DoubleArray] = [:]
    var bondStretch: OpenMM_CustomBondForce
    
    // bondTorsion - needs to be a separate force
    // bondBendTorsionBend
    // bondTorsionStretch - fusable with bondTorsion
    
    do {
      let energy = """
        10^2 *
        71.94 * stiffness / cubic_stretch^2 * (
          scale^2
          - scale^3
          + (7.0 / 12) * scale^4
          - fifth_power_term * scale^5
          + sixth_power_term * scale^6
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
      
      let chParameters = OpenMM_DoubleArray(size: 5)
      chParameters[0] = 474 * 0.01 * OpenMM_KJPerKcal //kjPerMolPerAJ
      chParameters[1] = 1.1120 * OpenMM_NmPerAngstrom
      chParameters[2] = 2.20
      chParameters[3] = 1.0 / 4
      chParameters[4] = 31.0 / 360
      stretchParameters[[1, 6]] = chParameters
      
      let ccParameters = OpenMM_DoubleArray(size: 5)
      ccParameters[0] = 455 * 0.01 * OpenMM_KJPerKcal // * kjPerMolPerAJ
      ccParameters[1] = 1.5270 * OpenMM_NmPerAngstrom
      ccParameters[2] = 3.00
      ccParameters[3] = 0.03
      ccParameters[4] = 0.17
      stretchParameters[[6, 6]] = ccParameters
      
      // TODO: For bonds ported from MM3, retain the old 2.55 cubic scaling
      // constant. Set 'fifth_power_term' and 'sixth_power_term' to zero.
      
      for bond in bonds {
        let atom1 = atoms[Int(bond[0])]
        let atom2 = atoms[Int(bond[1])]
        let element1 = min(atom1.element, atom2.element)
        let element2 = max(atom1.element, atom2.element)
        
        let parameters = stretchParameters[SIMD2(element1, element2)]!
        bondStretch.addBond(
          particles: SIMD2(truncatingIfNeeded: bond), parameters: parameters)
      }
    }
    
    struct BondBend {
      var parameters: [OpenMM_DoubleArray] = []
      
      init(
        bendStiffness: Double,
        stretchBendStiffness: Double,
        degrees: SIMD3<Double>,
        lengths: SIMD2<Double>
      ) {
        for i in 0..<3 {
          let _parameters = OpenMM_DoubleArray(size: 5)
          // WARNING: This is in an inconsistent unit system; very likely to
          // cause bugs.
          _parameters[0] = bendStiffness * OpenMM_KJPerKcal    //kjPerMolPerAJ
//          _parameters[0] = bendStiffness * kjPerMolPerAJ
          _parameters[1] = stretchBendStiffness * kjPerMolPerAJ
          _parameters[2] = degrees[i] * OpenMM_RadiansPerDegree
          _parameters[3] = lengths[0]
          _parameters[4] = lengths[1]
          parameters.append(_parameters)
        }
      }
    }
    var bendParameters: [SIMD3<UInt8>: BondBend] = [:]
    var angleTypes: [SIMD3<Int32>: Int] = [:]
    var bondBend: OpenMM_CustomCompoundBondForce
    
    do {
      #if false
      let energy = """
      bend + stretch_bend;
      bend = 1.5226 * bend_stiffness * (
        bend_scale^2
        - 1.4 * bend_scale^3
        + 5.6e-1 * bend_scale^4
        - 7.0e-1 * bend_scale^5
        + 9.0e-2 * bend_scale^6
      );
      stretch_bend = 1.7447e-9 * stretch_bend_stiffness * (
        distance(p1, p2) - length1 +
        distance(p2, p3) - length2
      ) * bend_scale;
      bend_scale = 0.01 * delta_theta;
      delta_theta = angle(p1, p2, p3) - equilibrium_angle;
      """
      #endif
      
      let energy = """
      (180 / 3.141592)^2 *
      0.021914 * bend_stiffness * (
        delta_theta^2
        - 0.014 * delta_theta^3
        + 5.6e-5 * delta_theta^4
        - 7.0e-7 * delta_theta^5
        + 9.0e-10 * delta_theta^6
      );
      delta_theta = angle(p1, p2, p3) - equilibrium_angle;
      """
      bondBend = OpenMM_CustomCompoundBondForce(numParticles: 3, energy: energy)
      bondBend.addPerBondParameter(name: "bend_stiffness")
      bondBend.addPerBondParameter(name: "stretch_bend_stiffness")
      bondBend.addPerBondParameter(name: "equilibrium_angle")
      bondBend.addPerBondParameter(name: "length1")
      bondBend.addPerBondParameter(name: "length2")
      
      bendParameters[[1, 6, 1]] = BondBend(
        bendStiffness: 0.540,
        stretchBendStiffness: 0.00 * 100,
        degrees: [107.70, 107.80, 107.70],
        lengths: [
          stretchParameters[[1, 6]]![1],
          stretchParameters[[1, 6]]![1],
        ])
      bendParameters[[1, 6, 6]] = BondBend(
        bendStiffness: 0.590,
        stretchBendStiffness: 0.100 * 100,
        degrees: [108.90, 109.47, 110.80],
        lengths: [
          stretchParameters[[1, 6]]![1],
          stretchParameters[[6, 6]]![1],
        ])
      bendParameters[[6, 6, 6]] = BondBend(
        bendStiffness: 0.740,
        stretchBendStiffness: 0.140 * 100,
        degrees: [109.50, 110.40, 111.80],
        lengths: [
          stretchParameters[[6, 6]]![1],
          stretchParameters[[6, 6]]![1],
        ])
      
      let particleArray = OpenMM_IntArray(size: 3)
      for bond in bonds123.keys {
        let centralID = Int(bond[1])
        let centralBonds = atomsToBondsMap[centralID]
        var totalNeighbors = 0
        var neighborList: SIMD2<Int32> = .init(repeating: -1)
        for i in 0..<4 {
          guard centralBonds[i] > -1 else {
            continue
          }
          let bond12 = bonds[Int(centralBonds[i])]
          
          let partnerID = getNot(id: Int32(centralID), from: bond12)
          if any(bond .== partnerID) {
            continue
          }
          guard totalNeighbors < 2 else {
            fatalError("Too many neighbors.")
          }
          neighborList[totalNeighbors] = partnerID
          totalNeighbors += 1
        }
        
        var neighborHydrogens: Int = 0
        var neighborCarbons: Int = 0
        for i in 0..<totalNeighbors {
          let atomID = neighborList[i]
          let element = atoms[Int(atomID)].element
          switch element {
          case 1: neighborHydrogens += 1
          case 6: neighborCarbons += 1
          default: fatalError("Unsupported element: \(element)")
          }
        }
        
        let atom1 = atoms[Int(bond[0])]
        let atom2 = atoms[Int(bond[1])]
        let atom3 = atoms[Int(bond[2])]
        let element1 = min(atom1.element, atom3.element)
        let element2 = atom2.element
        let element3 = max(atom1.element, atom3.element)
        
        var type: Int
        switch (neighborHydrogens, neighborCarbons) {
        case (0, 2): type = 1
        case (1, 1): type = 2
        case (2, 0): type = 3
        default: fatalError(
          "Invalid neighbor count: \((neighborHydrogens, neighborCarbons))")
        }
        angleTypes[bond] = type // WARNING: Don't forget this is off by 1.
        
        var atomID1 = Int(bond[0])
        var atomID3 = Int(bond[2])
        if !(atom1.element < atom3.element) {
          swap(&atomID1, &atomID3)
        }
        particleArray[0] = atomID1
        particleArray[1] = centralID
        particleArray[2] = atomID3
        
        let parameters = bendParameters[SIMD3(element1, element2, element3)]!
        let _parameters = parameters.parameters[type - 1]
        bondBend.addBond(particles: particleArray, parameters: _parameters)
      }
    }
    
    var bondBendBend: OpenMM_CustomCompoundBondForce
    
    do {
      let energy = """
      -1.5226e-4 * stiffness * (
        angle(p1, p2, p3) - equilibrium_angle1
      ) * (
        angle(p1, p2, p4) - equilibrium_angle2
      );
      """
      bondBendBend = OpenMM_CustomCompoundBondForce(
        numParticles: 4, energy: energy)
      bondBendBend.addPerBondParameter(name: "stiffness")
      bondBendBend.addPerBondParameter(name: "equilibrium_angle1")
      bondBendBend.addPerBondParameter(name: "equilibrium_angle2")
      
      var bendBendParameters: [SIMD3<UInt8>: Double] = [:]
      bendBendParameters[[1, 6, 1]] = 0.000
      bendBendParameters[[1, 6, 6]] = 0.350
      bendBendParameters[[6, 6, 6]] = 0.204
      
      var relativePairsDict: [SIMD3<UInt8>: Bool] = [:]
      for j in 0..<4 {
        let atom1 = j
        for k in 0..<4 where j != k {
          var atom3: Int?
          var atom4: Int?
          for l in 0..<4 where j != l && k != l {
            if atom3 == nil {
              atom3 = l
            } else if atom4 == nil {
              atom4 = l
            } else {
              fatalError("This should never happen.")
            }
          }
          
          guard let atom3, let atom4 else {
            fatalError("This should never happen.")
          }
          let indices = SIMD3(atom1, atom3, atom4)
          relativePairsDict[SIMD3(truncatingIfNeeded: indices)] = true
        }
      }
      let relativePairs: Array = relativePairsDict.keys.map { $0 }
      precondition(relativePairs.count == 4 * 3)
      
      let anglePairParticles = OpenMM_IntArray(size: 4)
      let anglePairParameters = OpenMM_DoubleArray(size: 3)
      for i in atoms.indices {
        if atoms[i].element == 1 {
          continue
        }
        let bondMap = atomsToBondsMap[Int(i)]
        precondition(!any(bondMap .== -1), "Carbon did not have 4 bonds.")
        
        var atomMap: SIMD4<Int32> = .init(repeating: -1)
        for j in 0..<4 {
          let bond = bonds[Int(bondMap[j])]
          atomMap[j] = getNot(id: Int32(i), from: bond)
        }
        
        for pair in relativePairs {
          var particles: SIMD4<Int32> = .init(repeating: -1)
          particles[0] = atomMap[Int(pair[0])]
          particles[1] = Int32(i)
          particles[2] = atomMap[Int(pair[1])]
          particles[3] = atomMap[Int(pair[2])]
          
          var stiffnesses: SIMD2<Double> = .init(repeating: -1)
          var angles: SIMD2<Double> = .init(repeating: -1)
          for j in 0..<2 {
            var atom1 = particles[0]
            let atom2 = particles[1]
            var atom3 = particles[2]
            if !(atom1 < atom3) {
              swap(&atom1, &atom3)
            }
            let type = angleTypes[SIMD3(atom1, atom2, atom3)]!
            
            var element1 = atoms[Int(atom1)].element
            let element2 = atoms[Int(atom2)].element
            var element3 = atoms[Int(atom3)].element
            if !(element1 < element3) {
              swap(&element1, &element3)
            }
            let bendKey = SIMD3<UInt8>(element1, element2, element3)
            let bendParams = bendParameters[bendKey]!.parameters[type - 1]
            let bendBendParams = bendBendParameters[bendKey]!
            angles[j] = bendParams[2]
            stiffnesses[j] = bendBendParams
          }
          var stiffness = stiffnesses[0] * stiffnesses[1]
          stiffness *= /*100 * */kjPerMolPerAJ
          
          for j in 0..<4 {
            anglePairParticles[j] = Int(particles[j])
          }
          anglePairParameters[0] = stiffness
          anglePairParameters[1] = angles[0]
          anglePairParameters[2] = angles[1]
          
          bondBendBend.addBond(
            particles: anglePairParticles, parameters: anglePairParameters)
        }
      }
    }
    
    var torsionParameters: [SIMD4<UInt8>: SIMD4<Double>] = [:]
    var bondTorsion: OpenMM_CustomCompoundBondForce
    
    do {
      let energy = """
      torsion + torsion_stretch;
      torsion = 0.5 * (
        V1 * (1 + cos(omega)) +
        V2 * (1 - cos(V2_scale * omega)) +
        V3 * term3
      );
      torsion_stretch = 0.5 * (1.0 / 12) * stiffness * (
        distance(p2, p3) - length
      ) * term3;
      term3 = 1 + cos(3 * omega);
      omega = dihedral(p1, p2, p3, p4);
      """
      bondTorsion = OpenMM_CustomCompoundBondForce(
        numParticles: 4, energy: energy)
      bondTorsion.addPerBondParameter(name: "V1")
      bondTorsion.addPerBondParameter(name: "V2")
      bondTorsion.addPerBondParameter(name: "V3")
      bondTorsion.addPerBondParameter(name: "V2_scale")
      bondTorsion.addPerBondParameter(name: "length")
      
      // Hard-code the fact that all torsions are between carbons. When we
      // support other atoms that can form >1 bonds, this needs to change.
      bondTorsion.addGlobalParameter(
        name: "stiffness", defaultValue: 0.660 * kjPerMolPerAJ)
      
      torsionParameters[[1, 6, 6, 1]] = [
        0.000 * OpenMM_KJPerKcal,
        0.008 * OpenMM_KJPerKcal,
        0.260 * OpenMM_KJPerKcal,
        6,
      ]
      torsionParameters[[1, 6, 6, 6]] = [
        0.000 * OpenMM_KJPerKcal,
        0.000 * OpenMM_KJPerKcal,
        0.290 * OpenMM_KJPerKcal,
        2,
      ]
      torsionParameters[[6, 6, 6, 6]] = [
        0.239 * OpenMM_KJPerKcal,
        0.024 * OpenMM_KJPerKcal,
        0.637 * OpenMM_KJPerKcal,
        2,
      ]
      
      let particleArray = OpenMM_IntArray(size: 4)
      let parametersArray = OpenMM_DoubleArray(size: 5)
      for bond in bonds1234.keys {
        var elements: SIMD4<UInt8> = .zero
        for i in 0..<4 {
          elements[i] = atoms[Int(bond[i])].element
        }
        precondition(elements[1] == elements[2])
        if !(elements[0] < elements[3]) {
          elements = SIMD4(
            elements[3], elements[2], elements[1], elements[0])
        }
        let stretchParams = stretchParameters[SIMD2(elements[1], elements[2])]!
        
        let torsionParams = torsionParameters[elements]!
        for i in 0..<4 {
          particleArray[i] = Int(bond[i])
        }
        for i in 0..<4 {
          parametersArray[i] = torsionParams[i]
        }
        parametersArray[4] = stretchParams[1]
        
        bondTorsion.addBond(
          particles: particleArray, parameters: parametersArray)
      }
    }
    
    // Debug the more complex forces one-by-one after vdW is working.
    
    bondStretch.transfer()
    bondBend.transfer()
//    bondBendBend.transfer()
//    bondTorsion.transfer()
    
    system.addForce(bondStretch)
    system.addForce(bondBend)
//    system.addForce(bondBendBend)
//    system.addForce(bondTorsion)
    
    // self.integrator = OpenMM_VerletIntegrator(stepSize: 2 * OpenMM_PsPerFs)
    self.integrator = OpenMM_LangevinMiddleIntegrator(
      temperature: 298, frictionCoeff: 91,
      stepSize: 2 * OpenMM_PsPerFs)
    self.context = OpenMM_Context(system: system, integrator: integrator)
    
    let positions = OpenMM_Vec3Array(size: atoms.count)
    for i in 0..<atoms.count {
      positions[i] = SIMD3(atoms[i].origin)
    }
    self.context.positions = positions
    precondition(context.platform.name == "HIP")
    
    self.provider = OpenMM_AtomProvider(
      psPerStep: 2 * OpenMM_PsPerFs,
      stepsPerFrame: fsPerFrame / 2,
      elements: atoms.map(\.element))
  }
  
  typealias VectorVield = (Int, SIMD3<Float>) -> SIMD3<Float>
  
  func velocityVectorField(_ closure: VectorVield) {
    let state = context.state(types: OpenMM_State_Positions)
    let positions = state.positions
    let velocities = OpenMM_Vec3Array(size: positions.size)
    
    for i in 0..<positions.size {
      let position = SIMD3<Float>(positions[i])
      let velocity = closure(i, position)
      velocities[i] = SIMD3(velocity)
    }
    context.velocities = velocities
  }
  
  func simulate(ps: Double) {
    let numFemtoseconds = Int(rint(ps * 1000))
    let numSteps = numFemtoseconds / 2
    let numFrames = numSteps / provider.stepsPerFrame
    precondition(
      numSteps % provider.stepsPerFrame == 0, "Uneven number of timesteps.")
    
    print("t = 0.000 ps")
    let state = context.state(types: OpenMM_State_Positions)
    provider.append(state: state, steps: 0)
    
    for t in 1...numFrames {
      let timestamp = Double(t * provider.stepsPerFrame * 2) / 1000
      print("t = \(String(format: "%.3f", timestamp)) ps")
      
      integrator.step(provider.stepsPerFrame)
      
      let state = context.state(types: OpenMM_State_Positions)
      provider.append(state: state, steps: provider.stepsPerFrame)
    }
  }
}
