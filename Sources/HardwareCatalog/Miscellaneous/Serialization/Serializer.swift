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
    let path = self.path + "/" + fileName + ".mrsim"
    let url = URL(filePath: path)
    return MRSimulation(
      renderer: renderer.renderingEngine, url: url)
  }
  
  func save(
    fileName: String,
    provider: OpenMM_AtomProvider,
    asText: Bool = false
  ) {
    // Allow 0.125 fs precision.
    var frameTimeInFs = rint(8 * 1000 * provider.psPerStep) / 8
    frameTimeInFs *= Double(provider.stepsPerFrame)
    let simulation = MRSimulation(
      renderer: renderer.renderingEngine,
      frameTimeInFs: frameTimeInFs,
      format: asText ? .plainText : .binary)
    
    for state in provider.states {
      let frame = MRFrame(atoms: state)
      simulation.append(frame)
    }
    
    var path = self.path + "/" + fileName + ".mrsim"
    if asText {
      path += "-txt"
    }
    let url = URL(filePath: path)
    simulation.save(url: url)
  }
}

struct SimulationAtomProvider: MRAtomProvider {
  var frameTimeInFs: Double
  var frames: [[MRAtom]] = []
  
  init(simulation: MRSimulation) {
    self.frameTimeInFs = simulation.frameTimeInFs
    for frameID in 0..<simulation.frameCount {
      let frame = simulation.frame(id: frameID)
      frames.append(frame.atoms)
    }
  }
  
  func atoms(time: MRTime) -> [MRAtom] {
    let frameID = min(time.absolute.frames, frames.count - 1)
    return frames[frameID]
  }
}

// The results of an OpenMM simulation. Currently, the data must be generated
// inside OpenMM at app launch time.

// Create a number of steps per frame; to add another frame, it validates the
// number of steps equals what you set. Also check that the number of atoms
// equals the number of atomic numbers.
class OpenMM_AtomProvider: MRAtomProvider {
  private(set) var psPerStep: Double
  private(set) var stepsPerFrame: Int
  private(set) var elements: [UInt8]
  /*private(set)*/ var states: [[MRAtom]] = []
  
  // Specify each atom's atomic number beforehand; OpenMM doesn't provide that.
  // Use element zero for ghost particles that keep diamondoids aligned to
  // groups of 32 atoms.
  init(
    psPerStep: Double,
    stepsPerFrame: Int,
    elements: [UInt8]
  ) {
    self.psPerStep = psPerStep
    self.stepsPerFrame = stepsPerFrame
    self.elements = elements
  }
  
  func append(state: OpenMM_State, steps: Int) {
    let positions = state.positions
    precondition(positions.size == elements.count, "Incorrect number of atoms.")
    if states.count == 0 {
      precondition(steps == 0, "First frame must have zero steps.")
    } else {
      // Disabling this check because it's getting in the way of other
      // design work.
//      precondition(steps == stepsPerFrame, "Incorrect number of steps.")
    }
    
    let atoms = [MRAtom](
      unsafeUninitializedCapacity: elements.count
    ) { buffer, count in
      for (i, element) in elements.enumerated() {
        guard element > 0 else {
          fatalError()
          continue
        }
        let posInNm = SIMD3<Float>(positions[i])
        let atom = MRAtom(origin: posInNm, element: element)
        buffer[count] = atom
        count += 1
      }
    }
    self.states.append(atoms)
  }
  
  // Move to the next frame. Call this **after** reading from the states.
  func atoms(time: MRTime) -> [MRAtom] {
    let fps = ContentView.frameRate
    precondition(120 % fps == 0)
    let frameAmplificationFactor = 120 / fps
    
    var frameID = time.absolute.frames * frameAmplificationFactor
    frameID = min(frameID, states.count - 1)
    return states[frameID]
  }
  
  func reset() {
    self.states = []
  }
}
