//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import AppKit
import KeyCodes
import Metal
import MolecularRenderer
import OpenMM
import simd

import HDL

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
  static let recycleSimulation: Bool = true
  static let productionRender: Bool = true
  static let programCamera: Bool = true
  
  init(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.eventTracker = coordinator.eventTracker
    
    let descriptor = MRRendererDescriptor()
    descriptor.url = Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    if Self.productionRender {
      descriptor.width = 360 // 720
      descriptor.height = 320 // 640
      descriptor.offline = true
    } else {
      descriptor.width = Int(ContentView.size)
      descriptor.height = Int(ContentView.size)
      descriptor.upscaleFactor = ContentView.upscaleFactor
    }
    
    self.renderingEngine = MRRenderer(descriptor: descriptor)
    self.gifSerializer = GIFSerializer(
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.serializer = Serializer(
      renderer: self,
      path: "/Users/philipturner/Documents/OpenMM/Renders/Exports")
    self.styleProvider = NanoStuff()
    initOpenMM()
    
    let openingWidth: Float = 10 // make this even
    let wallThicknessY: Float = 6 // this can be odd, ideally 1 - 3
    let wallThicknessX: Float = 5 // this can be odd, ideally 1 - 3
    let name: String = "\(Int(openingWidth))-\(Int(wallThicknessY))-\(Int(wallThicknessX))"
    
    #if false
    self.atomProvider = HousingVibrations(
      openingWidth: openingWidth,
      wallThicknessY: wallThicknessY,
      wallThicknessX: wallThicknessX).provider
    self.ioSimulation(name: name)
    #else
    self.ioSimulation(name: name)
    #endif
  }
}
