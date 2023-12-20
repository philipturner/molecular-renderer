//
//  Renderer+Setup.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation
import MolecularRenderer

extension Renderer {
  func initializeRenderingEngine() {
    let descriptor = MRRendererDescriptor()
    descriptor.url = Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
#if false
    // Defaults for offline rendering.
    descriptor.width = 720
    descriptor.height = 640
    descriptor.offline = true
#else
    // Defaults for online rendering.
    descriptor.width = Int(ContentView.size)
    descriptor.height = Int(ContentView.size)
    descriptor.upscaleFactor = ContentView.upscaleFactor
#endif
    descriptor.sceneSize = .extreme
    eventTracker.walkingSpeed = 5
    
    renderingEngine = MRRenderer(descriptor: descriptor)
    renderingEngine.setAtomStyleProvider(NanoStuff())
    renderingEngine.setQuality(
      MRQuality(minSamples: 3, maxSamples: 7, qualityCoefficient: 30))
  }
  
  func initializeExternalLibraries() {
    self.gifSerializer = GIFSerializer(
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.serializer = Serializer(
      renderer: self,
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    
    initOpenMM()
  }
  
  func initializeAtoms(_ atoms: [MRAtom]) {
    let provider = ArrayAtomProvider(atoms)
    renderingEngine.setAtomProvider(provider)
  }
}
