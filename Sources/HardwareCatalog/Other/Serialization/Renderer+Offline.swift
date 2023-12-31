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
  
  func renderSimulation(
    _ simulation: MRSimulation
  ) {
    func getFramesPerFrame(psPerSecond: Double? = nil) -> Int {
      if let psPerSecond {
        let fsPerFrame = simulation.frameTimeInFs
        var framesPerFrame = psPerSecond * 1000 / 100 / fsPerFrame
        if abs(framesPerFrame - rint(framesPerFrame)) < 0.001 {
          framesPerFrame = rint(framesPerFrame)
        } else {
          fatalError(
            "Indivisible playback speed: \(psPerSecond) / 100 / \(fsPerFrame)")
        }
        return Int(framesPerFrame)
      } else {
        // DO NOT return 2 here! That is for blur fusion!
        return 1
      }
    }
    let framesPerFrame = getFramesPerFrame()
    
    let numFrames = simulation.frameCount / framesPerFrame
    
    for frameID in 0..<numFrames {
      self.renderSemaphore.wait()
      let timeDouble = Double(frameID) / 100
      if frameID % 2 == 0 {
        print("Timestamp: \(String(format: "%.2f", timeDouble))")
      }
      
      let time = MRTime(
        absolute: frameID * framesPerFrame,
        relative: framesPerFrame,
        frameRate: 100 * framesPerFrame)
      let rotation = PlayerState.rotation(azimuth: 0, zenith: 0)
      let camera = MRCamera(
        position: [0, 0, 0],
        rotation: rotation,
        fovDegrees: 90)
      
      self.prepareRendering(
        animationTime: time,
        camera: camera,
        frameID: frameID,
        framesPerSecond: 100)
      
      renderingEngine.render { pixels in
        self.gifSerializer.addImage(pixels: pixels, blurFusion: 2)
        self.renderSemaphore.signal()
      }
    }
    renderingEngine.stopRendering()
  }
}
