//
//  Renderer+Setup.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 10/29/23.
//

import Foundation

extension Renderer {
  func renderSeries(names: [String]) {
    for name in names {
      print()
      self.gifSerializer = GIFSerializer(
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      
      let simulation = serializer.load(fileName: name)
      self.atomProvider = SimulationAtomProvider(simulation: simulation)
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
   
  func ioSimulation(name: String? = nil) {
    let simulationName = name ?? "SavedSimulation"
    if Self.recycleSimulation {
      let simulation = serializer.load(fileName: simulationName)
      self.atomProvider = SimulationAtomProvider(simulation: simulation)
      
      if Self.productionRender {
        renderSimulation(simulation)
        saveGIF(name: name)
      }
    } else {
      //    self.atomProvider = OctaneReference().provider
      //    self.atomProvider = DiamondoidCollision().provider
      //      self.atomProvider = VdwOscillator().provider
      
      serializer.save(
        fileName: simulationName,
        provider: atomProvider as! OpenMM_AtomProvider)
    }
  }
}
