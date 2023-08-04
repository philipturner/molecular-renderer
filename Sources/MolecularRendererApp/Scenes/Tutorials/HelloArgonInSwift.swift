//
//  HelloArgonInSwift.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/18/23.
//

import Foundation
import MolecularRenderer
import OpenMM

func simulateArgon(
  styleProvider: MRAtomStyleProvider
) -> OpenMM_AtomProvider {
  let provider = OpenMM_AtomProvider(
    psPerStep: 0.004, stepsPerFrame: 10, elements: [18, 18, 18])
  _simulateArgon(atomProvider: provider)
  return provider
}

func _simulateArgon(atomProvider: OpenMM_AtomProvider? = nil) {
  OpenMM_Platform.loadPlugins(
    directory: OpenMM_Platform.defaultPluginsDirectory!)
  
  let system = OpenMM_System()
  let nonbond = OpenMM_NonbondedForce()
  nonbond.transfer()
  system.addForce(nonbond)
  
  let initPosInNm = OpenMM_Vec3Array(size: 3)
  for a in 0..<3 {
    initPosInNm[a] = SIMD3<Double>(0.5 * Double(a), 0, 0)
    system.addParticle(mass: 39.95)
    nonbond.addParticle(charge: 0.0, sigma: 0.3350, epsilon: 0.996)
  }
  
  let integrator = OpenMM_VerletIntegrator(stepSize: 0.004)
  
  let context = OpenMM_Context(system: system, integrator: integrator)
  if atomProvider == nil { startPdb(platform: context.platform) }
  context.positions = initPosInNm
  
  var frameNum = 1
  while true {
    defer { frameNum += 1 }
    
    let state = context.state(types: .positions)
    if let atomProvider {
      atomProvider.append(state: state, steps: frameNum == 1 ? 0 : 10)
    } else {
      writePdbFrame(frameNum: frameNum, state: state)
    }
    
    if state.time >= 10 { break }
    integrator.step(10)
  }
}

func startPdb(platform: OpenMM_Platform) {
  print("REMARK  Using OpenMM platform \(platform.name)")
}

func writePdbFrame(frameNum: Int, state: OpenMM_State) {
  let posInNm = state.positions
  
  print("MODEL     \(frameNum)")
  for a in 0..<posInNm.size {
    let posInAng = posInNm[a] * 10
    var message = String(format: "ATOM  %5d  AR   AR     1    ", a + 1)
    message += String(
      format: "%8.3f%8.3f%8.3f  1.00  0.00",
      posInAng.x, posInAng.y, posInAng.z)
    print(message)
  }
  print("ENDMDL")
}
