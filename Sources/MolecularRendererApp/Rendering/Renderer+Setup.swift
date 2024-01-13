//
//  Renderer+Setup.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 12/20/23.
//

import Foundation
import HDL
import MolecularRenderer
import OpenMM
import QuartzCore

extension Renderer {
  func initializeExternalLibraries() {
    initializeOpenMM()
    initializeRenderingEngine()
  }
  
  func initializeCompilation(_ closure: () -> [Entity]) {
    let start = CACurrentMediaTime()
    let atoms = closure()
    let end = CACurrentMediaTime()
    print("atoms:", atoms.count)
    print("compile time:", String(format: "%.1f", (end - start) * 1e3), "ms")
    
    let provider = ArrayAtomProvider(atoms.map(MRAtom.init))
    renderingEngine.setAtomProvider(provider)
  }
  
  func initializeCompilation(_ closure: () -> [[Entity]]) {
    let start = CACurrentMediaTime()
    let frames = closure()
    let end = CACurrentMediaTime()
    
    var maxAtomCount = 0
    for frame in frames {
      maxAtomCount = max(maxAtomCount, frame.count)
    }
    print("atoms:", maxAtomCount)
    print("frames:", frames.count)
    print("setup time:", String(format: "%.1f", (end - start) * 1e3), "ms")
    
    var provider = AnimationAtomProvider([])
    for frame in frames {
      let mapped = frame.map {
        MRAtom(origin: $0.position, element: Int($0.atomicNumber))
      }
      provider.frames.append(mapped)
    }
    renderingEngine.setAtomProvider(provider)
  }
}

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
    descriptor.sceneSize = .small
    
    renderingEngine = MRRenderer(descriptor: descriptor)
    renderingEngine.setAtomStyleProvider(RendererStyle())
    renderingEngine.setQuality(
      MRQuality(minSamples: 3, maxSamples: 7, qualityCoefficient: 30))
  }
  
  func initializeOpenMM() {
    // Prevent energy measurement precision from becoming unacceptable at the
    // 100k-300k atom range.
    setenv("OPENMM_METAL_REDUCE_ENERGY_THREADGROUPS", "1024", 1)
    
    // Ensure the Metal plugin loads, even though the simulator framework is
    // supposed to load it.
    let directory = OpenMM_Platform.defaultPluginsDirectory!
    let plugins = OpenMM_Platform.loadPlugins(directory: directory)
    precondition(plugins != nil, "Failed to load plugins.")
  }
}

// MARK: - Atom Style Provider

private struct RendererStyle: MRAtomStyleProvider {
  var styles: [MRAtomStyle]
  
  var available: [Bool]
  
  init() {
    var radii: [Float] = [
      0.853, // 0
      0.930, // 1
      1.085, // 2
      
      3.100, // 3
      2.325, // 4
      1.550, // 5
      1.426, // 6
      1.201, // 7
      1.349, // 8
      1.279, // 9
      1.411, // 10
      
      3.100, // 11
      2.325, // 12
      1.938, // 13
      1.744, // 14
      1.635, // 15
      1.635, // 16
      1.573, // 17
      1.457, // 18
      
      3.875, // 19
      3.100, // 20
      2.868, // 21
      2.712, // 22
      2.558, // 23
      2.403, // 24
      2.325, // 25
      2.325, // 26
      2.325, // 27
      2.325, // 28
      2.325, // 29
      2.248, // 30
      2.093, // 31
      1.938, // 32
      1.705, // 33
      1.628, // 34
      1.550, // 35
      1.472, // 36
    ]
    radii += Array(repeating: 0, count: 79 - 36 - 1)
    radii += [
      2.625, // 79
    ]
    radii = radii.map { $0 * 1e-10 }
    
    var colors: [SIMD3<Float>] = [
      SIMD3(204,   0,   0), // 0
      SIMD3(199, 199, 199), // 1
      SIMD3(107, 115, 140), // 2
      
      SIMD3(  0, 128, 128), // 3
      SIMD3(250, 171, 255), // 4
      SIMD3( 51,  51, 150), // 5
      SIMD3( 99,  99,  99), // 6
      SIMD3( 31,  31,  99), // 7
      SIMD3(128,   0,   0), // 8
      SIMD3(  0,  99,  51), // 9
      SIMD3(107, 115, 140), // 10
      
      SIMD3(  0, 102, 102), // 11
      SIMD3(224, 153, 230), // 12
      SIMD3(128, 128, 255), // 13
      SIMD3( 41,  41,  41), // 14
      SIMD3( 84,  20, 128), // 15
      SIMD3(219, 150,   0), // 16
      SIMD3( 74,  99,   0), // 17
      SIMD3(107, 115, 140), // 18
      
      SIMD3(  0,  77,  77), // 19
      SIMD3(201, 140, 204), // 20
      SIMD3(106, 106, 130), // 21
      SIMD3(106, 106, 130), // 22
      SIMD3(106, 106, 130), // 23
      SIMD3(106, 106, 130), // 24
      SIMD3(106, 106, 130), // 25
      SIMD3(106, 106, 130), // 26
      SIMD3(106, 106, 130), // 27
      SIMD3(106, 106, 130), // 28
      SIMD3(106, 106, 130), // 29
      SIMD3(106, 106, 130), // 30
      SIMD3(153, 153, 204), // 31
      SIMD3(102, 115,  26), // 32
      SIMD3(153,  66, 179), // 33
      SIMD3(199,  79,   0), // 34
      SIMD3(  0, 102,  77), // 35
      SIMD3(107, 115, 140), // 36
    ]
    colors += Array(repeating: .zero, count: 79 - 36 - 1)
    colors += [
      SIMD3(212, 175, 55), // 79
    ]
    colors = colors.map { $0 / 255 }
    
    self.available = .init(repeating: false, count: 127)
    for i in 1...36 {
      self.available[i] = true
    }
    self.available[79] = true
    self.styles = []
    
  #if arch(x86_64)
    let atomColors: [SIMD3<Float16>] = []
  #else
    let atomColors = colors.map(SIMD3<Float16>.init)
  #endif
    let atomRadii = radii.map { $0 * 1e9 }.map(Float16.init)
    
    // colors:
    //   RGB color for each atom, ranging from 0 to 1 for each component.
    // radii:
    //   Enter all data in meters and Float32. They will be range-reduced to
    //   nanometers and converted to Float16.
    // available:
    //   Whether each element has a style. Anything without a style uses
    //   `radii[0]` and a black/magenta checkerboard pattern.
    self.styles = available.indices.map { i in
      let index = available[i] ? i : 0
      return MRAtomStyle(color: atomColors[index], radius: atomRadii[index])
    }
  }
}
