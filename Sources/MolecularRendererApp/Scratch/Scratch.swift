// Save as GitHub Gist instead of polluting the molecular-renderer source tree.

import Foundation
import HDL
import MM4
import Numerics

func createGeometry() -> [[Entity]] {
  var atoms: [Entity] = []
  var bonds: [SIMD2<UInt32>] = []
  
  let logicRod = LogicRod(length: 5)
  atoms = logicRod.topology.atoms
  bonds = logicRod.topology.bonds
  
  var paramsDesc = MM4ParametersDescriptor()
  paramsDesc.atomicNumbers = atoms.map(\.atomicNumber)
  paramsDesc.bonds = bonds
  let parameters = try! MM4Parameters(descriptor: paramsDesc)
  
  var forceFieldDesc = MM4ForceFieldDescriptor()
  forceFieldDesc.cutoffDistance = nil
  forceFieldDesc.parameters = parameters
  forceFieldDesc.integrator = .verlet
//  forceFieldDesc.integrator = .multipleTimeStep
  let forceField = try! MM4ForceField(descriptor: forceFieldDesc)
  forceField.positions = atoms.map(\.position)
  forceField.minimize()
  //574.4
  let startEnergy = forceField.energy.potential + forceField.energy.kinetic
  
  let start = cross_platform_media_time()
  var animation: [[Entity]] = []
  for frameID in 0...120 {
    let timeStep: Double = 1
    if frameID > 0 {
      forceField.simulate(time: timeStep)
    }
    if frameID % 10 == 0 {
      let time = Double(frameID) * timeStep
      
      let end = cross_platform_media_time()
      let nanoseconds = time * 0.001
      let days = (end - start) / 86400
      let nsPerDay = nanoseconds / days
      
      let endEnergy = forceField.energy.potential + forceField.energy.kinetic
      let drift = endEnergy - startEnergy
      
      print("frame=\(frameID), time=\(String(format: "%.3f", time)), speed=\(String(format: "%.1f", nsPerDay)) ns/day, drift=\(String(format: "%.1f", drift)) zJ")
    }
    
    var frame: [Entity] = []
    for (i, position) in forceField.positions.enumerated() {
      var atom = atoms[i]
      atom.position = position
      frame.append(atom)
    }
    animation.append(frame)
  }
  return animation
}
