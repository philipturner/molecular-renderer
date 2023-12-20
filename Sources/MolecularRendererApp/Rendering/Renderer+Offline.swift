//
//  Renderer+Offline.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

import Foundation
import MolecularRenderer

// MARK: - GIF

extension Renderer {
  func renderSeries(names: [String]) {
    for name in names {
      print()
      self.gifSerializer = GIFSerializer(
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      
      let simulation = serializer.load(fileName: name)
      let provider = SimulationAtomProvider(simulation: simulation)
      renderingEngine.setAtomProvider(provider)
      renderSimulation(simulation)
      
      let numFrames = gifSerializer.gif.frames.count
      print("ETA: \(numFrames / 21 / 2) - \(numFrames / 12 / 2) seconds.")
      gifSerializer.save(fileName: name)
      print("Saved the production render.")
    }
    exit(0)
  }
  
  func saveGIF(name: String? = nil) {
    let numFrames = gifSerializer.gif.frames.count
    print("ETA: \(numFrames / 21 / 2) - \(numFrames / 12 / 2) seconds.")
    gifSerializer.save(fileName: name ?? "SavedSimulation")
    print("Saved the production render.")
    exit(0)
  }
}

// MARK: - MRSimulation I/O

extension Renderer {
  static let defaultSimulationName: String = "SavedSimulation"
  
  func readSimulation(name: String? = nil) -> MRSimulation {
    let simulationName = name ?? Self.defaultSimulationName
    let simulation = serializer.load(fileName: simulationName)
    return simulation
  }
  
  func writeSimulation(_ provider: OpenMM_AtomProvider, name: String? = nil) {
    let simulationName = name ?? Self.defaultSimulationName
    serializer.save(fileName: simulationName, provider: provider)
  }
}

// MARK: - MRSimulation Rendering

extension Renderer {
  func renderOnline(_ simulation: MRSimulation) {
    let provider = SimulationAtomProvider(simulation: simulation)
    renderingEngine.setAtomProvider(provider)
  }
  
  func renderOffline(_ simulation: MRSimulation, name: String? = nil) {
    let simulationName = name ?? Self.defaultSimulationName
    let provider = SimulationAtomProvider(simulation: simulation)
    renderingEngine.setAtomProvider(provider)
    renderSimulation(simulation)
    saveGIF(name: simulationName)
  }
}
