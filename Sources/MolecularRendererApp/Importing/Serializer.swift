//
//  Serializer.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 7/23/23.
//

import Metal
import MolecularRenderer

class Serializer {
  unowned let renderer: Renderer
  var path: String
  
  init(renderer: Renderer, path: String) {
    self.renderer = renderer
    self.path = path
  }
  
  func load(fileName: String) -> MRSimulation {
    let path = self.path + "/" + fileName + ".mrsimulation"
    let url = URL(filePath: path)
    return MRSimulation(
      renderer: renderer.renderingEngine, url: url, method: .lzBitmap)
  }
  
  // TODO: Method to save a Nanosystems Figure3D
  
  func save(fileName: String, provider: OpenMM_AtomProvider) {
    var frameTimeInFs = rint(1000 * provider.psPerStep)
    frameTimeInFs *= Double(provider.stepsPerFrame)
    let simulation = MRSimulation(
      frameTimeInFs: frameTimeInFs,
      resolutionInApproxPm: 2)
    
    for state in provider.states {
      let frame = MRFrame(atoms: [state], metadata: [])
      simulation.append(frame)
    }
    
    let path = self.path + "/" + fileName + ".mrsimulation"
    let url = URL(filePath: path)
    simulation.serialize(
      renderer: renderer.renderingEngine, url: url, method: .lzBitmap)
  }
}
