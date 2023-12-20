//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import Metal
import Numerics
import simd

import HDL
import MM4
import MolecularRenderer
import QuartzCore

class Renderer {
  unowned let coordinator: Coordinator
  unowned let eventTracker: EventTracker
  
  // Rendering resources.
  var renderSemaphore: DispatchSemaphore = .init(value: 3)
  var renderingEngine: MRRenderer!
  
  // Geometry providers.
  var atomProvider: MRAtomProvider!
  var styleProvider: MRAtomStyleProvider!
  var animationFrameID: Int = 0
  var gifSerializer: GIFSerializer!
  var serializer: Serializer!
  
  // Camera scripting settings.
  static let recycleSimulation: Bool = false
  static let productionRender: Bool = false
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    do {
      let descriptor = MRRendererDescriptor()
      descriptor.url = Bundle.main.url(
        forResource: "MolecularRendererGPU", withExtension: "metallib")!
      if Self.productionRender {
        descriptor.width = 720
        descriptor.height = 640
        descriptor.offline = true
      } else {
        descriptor.width = Int(ContentView.size)
        descriptor.height = Int(ContentView.size)
        descriptor.upscaleFactor = ContentView.upscaleFactor
      }
      
      descriptor.sceneSize = .extreme
      eventTracker.walkingSpeed = 5
      
      self.renderingEngine = MRRenderer(descriptor: descriptor)
      self.gifSerializer = GIFSerializer(
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.serializer = Serializer(
        renderer: self,
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.styleProvider = NanoStuff()
      initOpenMM()
    }
    
    let start = CACurrentMediaTime()
    let atoms = createNanomachinery()
    let end = CACurrentMediaTime()
    print("atom count:", atoms.count)
    print("compile time:", Int((end - start) * 1e3), "ms")
    self.atomProvider = ArrayAtomProvider(atoms)
  }
}
