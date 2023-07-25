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
      resolutionInApproxPm: 1)
    
    for state in provider.states {
      let frame = MRFrame(atoms: [state], metadata: [Data()])
      simulation.append(frame)
    }
    
    let path = self.path + "/" + fileName + ".mrsimulation"
    let url = URL(filePath: path)
    simulation.serialize(
      renderer: renderer.renderingEngine, url: url, method: .lzBitmap)
  }
}

struct SimulationAtomProvider: MRAtomProvider {
  var frameTimeInFs: Double
  var frames: [[MRAtom]] = []
  
  init(simulation: MRSimulation, batchIndex: Int) {
    self.frameTimeInFs = simulation.frameTimeInFs
    for frame in simulation.frames {
      self.frames.append(frame.atoms[batchIndex])
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
