//
//  HelloEthaneInSwift.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/1/23.
//

import Foundation
import MolecularRenderer
import OpenMM

// Scope all the constants as `fileprivate`.
fileprivate struct SimulationConstants {
  static let useConstraints: Bool = false
  static let stepSizeInFs: Double = 2
  static let reportIntervalInFs: Double = 10
  static let simulationTimeInPs: Double = 100
  static let wantEnergy: Bool = true
  
  static let coulomb14Scale: Double = 0.5
  static let lennardJones14Scale: Double = 0.5
  
  static var numSilentSteps: Int {
    Int(rint(reportIntervalInFs / stepSizeInFs))
  }
}

fileprivate struct AtomType {
  var mass, charge, vdwRadiusInAngstroms, vdwEnergyInKcal: Double
  static let dict: [String: AtomType] = [
    "H": .init(
      mass: 1.008, charge: 0.0605,
      vdwRadiusInAngstroms: 1.4870, vdwEnergyInKcal: 0.0157),
    "C": .init(
      mass: 12.011, charge: -0.1815,
      vdwRadiusInAngstroms: 1.9080, vdwEnergyInKcal: 0.1094),
  ]
}

fileprivate struct BondType {
  var nominalLengthInAngstroms, stiffnessInKcalPerAngstrom2: Double
  var canConstrain: Bool
  static let dict: [String: BondType] = [
    "CC": .init(
      nominalLengthInAngstroms: 1.527, stiffnessInKcalPerAngstrom2: 310.0,
      canConstrain: false),
    "CH": .init(
      nominalLengthInAngstroms: 1.09, stiffnessInKcalPerAngstrom2: 340.0,
      canConstrain: true),
  ]
}

fileprivate struct AngleType {
  var nominalAngleInDegrees, stiffnessInKcalPerRadian2: Double
  static let dict: [String: AngleType] = [
    "HCC": .init(nominalAngleInDegrees: 109.5, stiffnessInKcalPerRadian2: 50.0),
    "HCH": .init(nominalAngleInDegrees: 109.5, stiffnessInKcalPerRadian2: 35.0),
  ]
}

fileprivate struct TorsionType {
  var periodicity: Int
  var phaseInDegrees, amplitudeInKcal: Double
  static let dict: [String: TorsionType] = [
    "HCCH": .init(periodicity: 3, phaseInDegrees: 0.0, amplitudeInKcal: 0.150),
  ]
}

fileprivate typealias Atom = (
  type: String, initPosInAng: SIMD3<Double>, posInAng: SIMD3<Double>
)

extension SimulationConstants {
  // Atoms are `var` for convenience, as we modify them frequently.
  static var atoms: [Atom] = [
    ("C", [-0.7605,   0,   0   ], .zero),
    ("C", [ 0.7605,   0,   0   ], .zero),
    ("H", [-1.135,  1.03,  0   ], .zero), // bonded to C1
    ("H", [-1.135, -0.51,  0.89], .zero),
    ("H", [-1.135, -0.51, -0.89], .zero),
    ("H", [ 1.135,  1.03,  0   ], .zero), // bonded to C2
    ("H", [ 1.135, -0.51,  0.89], .zero),
    ("H", [ 1.135, -0.51, -0.89], .zero),
  ]
  
  static let bonds: [(type: String, atoms: SIMD2<Int>)] = [
    ("CC", [0, 1]),
    ("CH", [0, 2]), ("CH", [0, 3]), ("CH", [0, 4]), // C1 methyl
    ("CH", [1, 5]), ("CH", [1, 6]), ("CH", [1, 7]), // C2 methyl
  ]
  
  static let angles: [(type: String, atoms: SIMD3<Int>)] = [
    ("HCC", [2, 0, 1]), ("HCC", [3, 0, 1]), ("HCC", [4, 0, 1]), // C1 methyl
    ("HCH", [2, 0, 3]), ("HCH", [2, 0, 4]), ("HCH", [3, 0, 4]),
    ("HCC", [5, 1, 0]), ("HCC", [6, 1, 0]), ("HCC", [7, 1, 0]), // C2 methyl
    ("HCH", [5, 1, 6]), ("HCH", [5, 1, 7]), ("HCH", [6, 1, 7]),
  ]
  
  static let torsions: [(type: String, atoms: SIMD4<Int>)] = [
    ("HCCH", [2, 0, 1, 5]), ("HCCH", [2, 0, 1, 6]), ("HCCH", [2, 0, 1, 7]),
    ("HCCH", [3, 0, 1, 5]), ("HCCH", [3, 0, 1, 6]), ("HCCH", [3, 0, 1, 7]),
    ("HCCH", [4, 0, 1, 5]), ("HCCH", [4, 0, 1, 6]), ("HCCH", [4, 0, 1, 7]),
  ]
}

fileprivate class MyOpenMMData {
  var system: OpenMM_System
  var integrator: OpenMM_Integrator
  var context: OpenMM_Context
  var provider: OpenMM_DynamicAtomProvider
  
  init(atoms: [Atom], stepSizeInFs: Double, platformName: inout String) {
    let pluginsDirectory = OpenMM_Platform.defaultPluginsDirectory!
    OpenMM_Platform.loadPlugins(directory: pluginsDirectory)
    self.system = OpenMM_System()
    
    let nonbond = OpenMM_NonbondedForce()
    let bondStretch = OpenMM_HarmonicBondForce()
    let bondBend = OpenMM_HarmonicAngleForce()
    let bondTorsion = OpenMM_PeriodicTorsionForce()
    nonbond.transfer()
    bondStretch.transfer()
    bondBend.transfer()
    bondTorsion.transfer()
    system.addForce(nonbond)
    system.addForce(bondStretch)
    system.addForce(bondBend)
    system.addForce(bondTorsion)
    
    fatalError()
  }
}
