//
//  HelloSodiumChlorideInSwift.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import Foundation
import MolecularRenderer
import OpenMM

// Scope all the constants as `fileprivate`.
fileprivate struct SimulationConstants {
  static let temperature: Double = 300
  static let frictionInPerPs: Double = 91
  static let solventDielectric: Double = 80
  static let soluteDielectric: Double = 2
  
  static let stepSizeInFs: Double = 4
  static let reportIntervalInFs: Double = 50
  static let simulationTimeInPs: Double = 100
  static let wantEnergy: Bool = true
  
  static let sodium: MyAtomInfo = .init(
    element: 11, mass: 22.99, charge: 1, vdwRadiusInAng: 1.8680,
    vdwEnergyInKcal: 0.00277, gbsaRadiusInAng: 1.992, gbsaScaleFactor: 0.8)
  static let chlorine: MyAtomInfo = .init(
    element: 17, mass: 35.45, charge: -1, vdwRadiusInAng: 2.4700,
    vdwEnergyInKcal: 0.1000, gbsaRadiusInAng: 1.735, gbsaScaleFactor: 0.8)
  
  static let atoms: [MyAtomInfo] = [
    sodium.withInitPos([8, 0, 0]),
    chlorine.withInitPos([-8, 0, 0]),
    sodium.withInitPos([0, 9, 0]),
    chlorine.withInitPos([0, -9, 0]),
    sodium.withInitPos([0, 0, -10]),
    chlorine.withInitPos([0, 0, 10])
  ]
}

fileprivate struct MyAtomInfo {
  var element: UInt8
  var mass, charge, vdwRadiusInAng, vdwEnergyInKcal,
      gbsaRadiusInAng, gbsaScaleFactor: Double
  var initPosInAng: SIMD3<Double> = .zero
  var posInAng: SIMD3<Double> = .zero
  
  func withInitPos(_ pos: SIMD3<Double>) -> MyAtomInfo {
    var copy = self
    copy.initPosInAng = pos
    return copy
  }
}

extension SimulationConstants {
  static var numReports: Int {
    Int(simulationTimeInPs * 1000 / reportIntervalInFs + 0.5)
  }
  static var numSilentSteps: Int {
    Int(reportIntervalInFs / stepSizeInFs + 0.5)
  }
  static func omm(platformName: inout String) -> MyOpenMMData {
    MyOpenMMData(
      atoms: atoms, temperature: temperature, frictionInPerPs: frictionInPerPs,
      solventDielectric: solventDielectric, soluteDielectric: soluteDielectric,
      stepSizeInFs: stepSizeInFs, platformName: &platformName)
  }
}

func simulateSodiumChloride() -> OpenMM_AtomProvider {
  var platformName: String = ""
  let omm = SimulationConstants.omm(platformName: &platformName)
  
  var atoms = SimulationConstants.atoms
  var time: Double = 0
  var energyInKT: Double = 0
  
  myGetOpenMMState(
    omm, wantEnergy: SimulationConstants.wantEnergy, timeInPs: &time,
    energyInKT: &energyInKT, atoms: &atoms)
  myWriteMRFrame(omm, frameNum: 1)
  
  for frame in 2...SimulationConstants.numReports {
    myStepWithOpenMM(omm, numSteps: SimulationConstants.numSilentSteps)
    myGetOpenMMState(
      omm, wantEnergy: SimulationConstants.wantEnergy, timeInPs: &time,
      energyInKT: &energyInKT, atoms: &atoms)
    myWriteMRFrame(omm, frameNum: frame)
  }
  
  // No need to terminate because the Swift wrapper abstracts away memory
  // management.
  return omm.provider
}

fileprivate class MyOpenMMData {
  var system: OpenMM_System
  var context: OpenMM_Context
  var integrator: OpenMM_Integrator
  var provider: OpenMM_AtomProvider
  
  init(
    atoms: [MyAtomInfo],
    temperature: Double,
    frictionInPerPs: Double,
    solventDielectric: Double,
    soluteDielectric: Double,
    stepSizeInFs: Double,
    platformName: inout String
  ) {
    OpenMM_Platform.loadPlugins(
      directory: OpenMM_Platform.defaultPluginsDirectory!)
    self.system = OpenMM_System()
    
    let nonbond = OpenMM_NonbondedForce()
    let gbsa = OpenMM_GBSAOBCForce()
    nonbond.transfer()
    self.system.addForce(nonbond)
    gbsa.transfer()
    self.system.addForce(gbsa)
    
    gbsa.solventDielectric = solventDielectric
    gbsa.soluteDielectric = soluteDielectric
    
    let initialPosInNm = OpenMM_Vec3Array(size: 0)
    for atom in atoms {
      system.addParticle(mass: atom.mass)
      nonbond.addParticle(
        charge: atom.charge,
        sigma: atom
          .vdwRadiusInAng * OpenMM_NmPerAngstrom * OpenMM_SigmaPerVdwRadius,
        epsilon: atom.vdwEnergyInKcal * OpenMM_KJPerKcal)
      gbsa.addParticle(
        charge: atom.charge,
        radius: atom.gbsaRadiusInAng * OpenMM_NmPerAngstrom,
        scalingFactor: atom.gbsaScaleFactor)
      initialPosInNm.append(atom.initPosInAng * OpenMM_NmPerAngstrom)
    }
    
    self.integrator = OpenMM_LangevinMiddleIntegrator(
      temperature: temperature, frictionCoeff: frictionInPerPs,
      stepSize: stepSizeInFs * OpenMM_PsPerFs)
    self.context = OpenMM_Context(system: system, integrator: integrator)
    context.positions = initialPosInNm
    platformName = context.platform.name
    
    self.provider = OpenMM_AtomProvider(
      psPerStep: stepSizeInFs * OpenMM_PsPerFs,
      stepsPerFrame: SimulationConstants.numSilentSteps,
      elements: atoms.map(\.element))
  }
}

fileprivate func myGetOpenMMState(
  _ omm: MyOpenMMData, wantEnergy: Bool, timeInPs: inout Double,
  energyInKT: inout Double, atoms: inout [MyAtomInfo]
) {
  var types: OpenMM_State.DataType
  if wantEnergy {
    types = [.positions, .velocities, .energy]
  } else {
    types = .positions
  }

  let state = omm.context.state(types: types)
  timeInPs = state.time
  
  let posArrayInNm = state.positions
  for n in 0..<atoms.count {
    atoms[n].posInAng = posArrayInNm[n] * OpenMM_AngstromsPerNm
  }
  
  let timeRepr = String(format: "%.1f", timeInPs)
  energyInKT = 0
  if wantEnergy {
    let ktPerKJ: Double = 2.479
    energyInKT = (state.potentialEnergy + state.kineticEnergy) * ktPerKJ
    print("time: \(timeRepr) ps, energy: \(energyInKT) kT")
  } else {
    print("time: \(timeRepr) ps")
  }
}

fileprivate func myStepWithOpenMM(_ omm: MyOpenMMData, numSteps: Int) {
  omm.integrator.step(numSteps)
}

// Do not write to PDB; immediately render to DynamicAtomProvider. And instead
// of initializing in the caller, a function inside this file should initialize
// the `OpenMM_DynamicAtomProvider` object. That abstracts away the specific
// step size.
fileprivate func myWriteMRFrame(
  _ omm: MyOpenMMData,
  frameNum: Int
) {
  var numSteps: Int
  if frameNum == 1 {
    numSteps = 0
  } else {
    numSteps = SimulationConstants.numSilentSteps
  }
  let state = omm.context.state(types: .positions)
  omm.provider.append(state: state, steps: numSteps)
}
