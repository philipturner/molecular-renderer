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
import xTB

// MARK: - Code Invocation

extension Renderer {
  func initializeCompilation(_ closure: () -> [Entity]) {
    let start = CACurrentMediaTime()
    let atoms = closure()
    let end = CACurrentMediaTime()
    print("atoms:", atoms.count)
    print("compile time:", String(format: "%.1f", (end - start) * 1e3), "ms")
    
    let provider = ArrayAtomProvider(atoms.map(\.storage))
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
      let mapped = frame.map(\.storage)
      provider.frames.append(mapped)
    }
    renderingEngine.setAtomProvider(provider)
  }
}

// MARK: - Library Setup

extension Renderer {
  func initializeExternalLibraries() {
    initializeRenderingEngine()
    initializeOpenMM()
    initializeXTB()
  }
  
  func initializeRenderingEngine() {
    let descriptor = MRRendererDescriptor()
    
    // TODO: Fix this, so the client loads the shader library.
    descriptor.url = Bundle.main.url(
      forResource: "MolecularRendererGPU", withExtension: "metallib")!
    
    guard ContentView.size % ContentView.upscaleFactor == 0 else {
      fatalError("Invalid content view size.")
    }
    descriptor.intermediateTextureSize = Int(
      ContentView.size / ContentView.upscaleFactor)
    descriptor.upscaleFactor = ContentView.upscaleFactor
    descriptor.reportPerformance = false
    
    renderingEngine = MRRenderer(descriptor: descriptor)
    renderingEngine.setAtomStyles(
      Renderer.createAtomStyles())
    renderingEngine.setQuality(
      MRQuality(minSamples: 3, maxSamples: 7, qualityCoefficient: 30))
  }
  
  // If OpenMM is not set up, comment out the call to this function in
  // 'initializeExternalLibraries'.
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
  
  // If xTB is not set up, comment out the call to this function in
  // 'initializeExternalLibraries'.
  func initializeXTB() {
    // Find the number of P-cores.
    var performanceCoreCount: Int64 = .zero
    var size = MemoryLayout<Int64>.stride
    let errorCode = sysctlbyname(
      "hw.perflevel0.physicalcpu", &performanceCoreCount, &size, nil, 0)
    guard errorCode == 0 else {
      fatalError("Failed to acquire core count.")
    }
    
    // Prepare the environment for maximum performance with xTB.
    setenv("OMP_STACKSIZE", "2G", 1)
    setenv("OMP_NUM_THREADS", "\(performanceCoreCount)", 1)
    
    // MARK: - Users, replace this with your username.

    // Fix the GFN-FF crash.
    FileManager.default.changeCurrentDirectoryPath("/Users/philipturner")
    
    // Copy the dylib from Homebrew Cellar to the folder for hacked dylibs. Use
    // 'otool' to replace the OpenBLAS dependency with Accelerate. To do this:
    // - copy libxtb.dylib into custom folder
    // - otool -L "path to libxtb.dylib"
    // - find the address of the OpenBLAS in the output
    // - install_name_tool -change "path to libopenblas.dylib" \
    //   "/System/Library/Frameworks/Accelerate.framework/Versions/A/Accelerate" \
    //   "path to libxtb.dylib"
    //
    // I will eventually have better documentation to validate that you have
    // correctly injected Accelerate. It is critical that quantum mechanical
    // simulation performance is as fast as possible. GFN2-xTB is painfully
    // slow with OpenBLAS, especially for small systems.
    
    // MARK: - Users, replace this with your dylib path.

    // Load the 'xtb' dylib.
    let pathPart1 = "/Users/philipturner/Documents/OpenMM"
    let pathPart2 = "/bypass_dependencies/libxtb.6.dylib"
    xTB_Library.useLibrary(at: pathPart1 + pathPart2)
    try! xTB_Library.loadLibrary()

    // Mute the output to the console.
    xTB_Environment.verbosity = .muted
  }
}
