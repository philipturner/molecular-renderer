//
//  Provider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation
import QuartzCore

// TODO: Make this the first file moved to the Swift package, 'Atom' the second.

// NOTE: These protocols cannot be part of the C API. Rather, create a
// `StaticStyleProvider` struct with pointers to lists.

// TODO: Remove the requirement for an initializer that accepts a URL.

// A 'DynamicAtomProvider' would change its contents in real-time, streaming
// a pre-recorded simulation directly from the disk. A real-time molecular
// dynamics simulation does not count as an external provider, because it is
// part of MolecularRenderer.
/*public*/ protocol /*MR*/StaticAtomProvider {
  var atoms: [/*MR*/Atom] { get }
  
  // Optional URL, if this must access the internet or file system.
//  init(url: URL?)
}

// This must be set before adding any atoms via 'StaticAtomProvider'.
/*public*/ protocol StaticStyleProvider {
  // Return all data in meters and Float32. The receiver will then range-reduce
  // to nanometers and cast to Float16.
  var radii: [Float] { get }
  
  // RGB color for each atom, ranging from 0 to 1 for each component.
  var colors: [SIMD3<Float>] { get }
  
  // Intensity of the camera-centered light for Blinn-Phong shading.
  // Example: 40.0 for the colors hard-coded into QuteMol's source code.
  // Example: 50.0 for the QuteMol color scheme from the ART file.
  var lightPower: Float { get }
  
  // The range of atomic numbers (inclusive). Anything outside this range uses
  // value in `radii` at index 0 and a black/magenta checkerboard pattern. The
  // range's start index must always be 1.
  //
  // TODO: Use this range instead of hard-coding the number 36 into the parsers.
  var atomicNumbers: ClosedRange<Int> { get }
  
  // Optional URL, if this must access the internet or file system.
//  init(url: URL?)
}

// A 'DynamicDownloader' would issue a Metal fast resource loading command,
// which asynchronously returns the data just in time for rendering.
internal struct StaticDownloader {
  private var url: URL
  private(set) var latency: Double
  private(set) var data: Data
  var string: String { String(data: data, encoding: .utf8)! }
  
  // Immediately downloads the file upon initialization, blocking the caller.
  init(url: URL) throws {
    let start = CACurrentMediaTime()
    let data = try Data(contentsOf: url)
    let end = CACurrentMediaTime()
    
    self.url = url
    self.data = data
    self.latency = end - start
  }
  
  func logLatency() {
    // TODO: Query a global variable that determines whether events like this
    // are logged.
    print("Downloaded in \(latencyRepr(latency))")
    print("- path: \(url)")
  }
}
