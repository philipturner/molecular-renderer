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
  static let programCamera: Bool = false
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    do {
      let descriptor = MRRendererDescriptor()
      descriptor.url = Bundle.main.url(
        forResource: "MolecularRendererGPU", withExtension: "metallib")!
      if Self.productionRender {
        // TODO: Export this next movie as 1280x720 instead of 720x640.
        descriptor.width = 720
        descriptor.height = 640
        descriptor.offline = true
      } else {
        descriptor.width = Int(ContentView.size)
        descriptor.height = Int(ContentView.size)
        descriptor.upscaleFactor = ContentView.upscaleFactor
      }
      
      // TODO: Revert to small systems mode after the project is done.
      descriptor.largeSystemsMode = true
      
      self.renderingEngine = MRRenderer(descriptor: descriptor)
      self.gifSerializer = GIFSerializer(
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.serializer = Serializer(
        renderer: self,
        path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
      self.styleProvider = NanoStuff()
      initOpenMM()
    }
    
    //    self.atomProvider = Bootstrapping.Animation()
    
    var atoms1 = createSilyleneTooltip(sp3: false)
    var atoms2 = createSilyleneTooltip(sp3: true)
    for i in atoms1.indices {
      atoms1[i].origin.x -= 0.5
      atoms2[i].origin.x += 0.5
    }
    self.atomProvider = ArrayAtomProvider(
      atoms1 + atoms2)
  }
}
