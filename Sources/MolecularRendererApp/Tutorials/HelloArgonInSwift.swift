//
//  HelloArgonInSwift.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/18/23.
//

import Foundation
import OpenMM

func simulateArgon() {
  let pluginList = OpenMM_Platform.loadPlugins(
    directory: OpenMM_Platform.defaultPluginsDirectory!)
  
  let system = OpenMM_System()
  let nonbond = OpenMM_NonbondedForce()
  nonbond.transfer()
  system.addForce(nonbond)
  
  let initPosInNm = OpenMM_Vec3Array(size: 3)
  for a in 0..<3 {
    let posNm = SIMD3<Double>(0.5 * Double(a), 0, 0)
    initPosInNm[a] = posNm
    
    system.addParticle(mass: 39.95)
    
    nonbond.addParticle(charge: 0.0, sigma: 0.3350, epsilon: 0.996)
  }
  
  let integrator = OpenMM_VerletIntegrator(stepSize: 0.004)
  
  let context = OpenMM_Context(system: system, integrator: integrator)
  let platform = context.platform
  
}

// TODO: Output the results of this simulation to a Swift array, so you can view
// it in the molecular renderer.
func writePdbFrame(frameNum: Int, state: OpenMM_State) {
  let posInNm = state.positions
  
  print("MODEL     \(frameNum)")
  for a in 0..<posInNm.size {
    let posInAng = posInNm[a] * 10
    var message = String(format: "ATOM  %5d  AR   AR     1    ", a + 1)
    message += String(
      format: "%8.3f%8.3f%8.3f  1.00  0.00\n",
      posInAng.x, posInAng.y, posInAng.z)
    print(message)
  }
  print("ENDMDL")
}
