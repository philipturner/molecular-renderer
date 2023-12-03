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
import MM4

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
      descriptor.width = 720
      descriptor.height = 640
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
    
    // Use an adamantane cage to test the new MM4. You can replace one of the
    // carbons with a sigma bond, creating a 5-membered ring.
    let lattice = Lattice<Cubic> { h, k, l in
      Bounds { 4 * h + 4 * k + 4 * l }
      Material { .elemental(.carbon) }
      
      Volume {
        Origin { 2 * h + 2 * k + 2 * l }
        Origin { 0.25 * (h + k - l) }
        
        // Remove the front plane.
        Convex {
          Origin { 0.25 * (h + k + l) }
          Plane { h + k + l }
        }
        
        func triangleCut(sign: Float) {
          Convex {
            Origin { 0.25 * sign * (h - k - l) }
            Plane { sign * (h - k / 2 - l / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (k - l - h) }
            Plane { sign * (k - l / 2 - h / 2) }
          }
          Convex {
            Origin { 0.25 * sign * (l - h - k) }
            Plane { sign * (l - h / 2 - k / 2) }
          }
        }
        
        // Remove three sides forming a triangle.
        triangleCut(sign: +1)
        
        // Remove their opposites.
        triangleCut(sign: -1)
        
        // Remove the back plane.
        Convex {
          Origin { -0.25 * (h + k + l) }
          Plane { -(h + k + l) }
        }
        
        Replace { .empty }
      }
    }
    
    let latticeAtoms = lattice.entities.map(MRAtom.init)
    let diamondoid = Diamondoid(atoms: latticeAtoms)
    self.atomProvider = ArrayAtomProvider(diamondoid.atoms)
  }
}
