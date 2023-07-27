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
  
  func load(fileName: String) -> NewMRSimulation {
    let path = self.path + "/" + fileName + ".mrsimulation"
    let url = URL(filePath: path)
    return NewMRSimulation(
      renderer: renderer.renderingEngine, url: url)
  }
  
  func save(fileName: String, provider: OpenMM_AtomProvider) {
    var frameTimeInFs = rint(1000 * provider.psPerStep)
    frameTimeInFs *= Double(provider.stepsPerFrame)
    let simulation = NewMRSimulation(
      renderer: renderer.renderingEngine,
      frameTimeInFs: frameTimeInFs)
    
    for state in provider.states {
      let frame = NewMRFrame(atoms: state)
      simulation.append(frame)
    }
    
    let path = self.path + "/" + fileName + ".mrsimulation"
    let url = URL(filePath: path)
    simulation.save(url: url)
  }
}

struct SimulationAtomProvider: MRAtomProvider {
  var frameTimeInFs: Double
  var frames: [[MRAtom]] = []
  
  init(simulation: NewMRSimulation, batchIndex: Int) {
    self.frameTimeInFs = simulation.frameTimeInFs
    for frameID in 0..<simulation.frameCount {
      let frame = simulation.frame(id: frameID)
      frames.append(frame.atoms)
    }
    
    let ps = (frameTimeInFs * 120) / 1000
    print()
    print("Replaying at \(ps) ps/s.")
  }
  
  func atoms(time: MRTimeContext) -> [MRAtom] {
    let frameID = min(time.absolute.frames, frames.count - 1)
    let ps = 1 / 1000 * Double(frameID) * frameTimeInFs
    print("Replaying frame: \(ps) ps")
    
    return frames[frameID]
  }
}
