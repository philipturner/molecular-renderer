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
  static let recycleSimulation: Bool = false
  static let productionRender: Bool = false
  static let programCamera: Bool = false
  
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
    
    let openingWidth: Float = 6 // make this even
    let wallThicknessY: Float = 3 // this can be odd, ideally 1 - 3
    let wallThicknessX: Float = 2 // this can be odd, ideally 1 - 3
        
    let lattice = Lattice<Hexagonal> { h, k, l in
      let h2k = h + 2 * k
      let _2h = 2 * h
      Bounds { 24 * _2h + 24 * h2k + 20 * l }
      Material { .elemental(.carbon) }
      
      let h2k2 = h2k / 2
      
      Volume {
        Origin { 12 * _2h + 12 * h2k }
        if (Int(openingWidth) / 2) % 2 == 0 {
          Origin { 0.5 * h + 0.0 * h2k2 }
        }
        
        Concave {
          for direction in [h, h2k2, -h, -h2k2] {
            Convex {
              Origin { (openingWidth / 2) * direction }
              Plane { -direction }
            }
          }
        }
        for direction in [h2k2, -h2k2] {
          Convex {
            Origin { (openingWidth / 2) * direction }
            Origin { wallThicknessY * direction }
            Plane { direction }
          }
        }
        for direction in [h, -h] {
          Convex {
            Origin { (openingWidth / 2) * direction }
            Origin { wallThicknessX * direction }
            Plane { direction }
          }
        }
        
        Replace { .empty }
      }
    }
    
    let latticeAtoms = lattice.entities.map(MRAtom.init)
    atomProvider = ArrayAtomProvider(latticeAtoms)
  }
}
