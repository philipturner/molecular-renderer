//
//  MRProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation

// NOTE: These protocols cannot be part of the C API. Rather, create a C struct
// with pointers to lists. The Swift package will internally create an object
// conforming to `MRStaticStyleProvider`, which wraps the data imported from C.

// A 'DynamicAtomProvider' would change its contents in real-time, streaming
// a pre-recorded simulation directly from the disk. A real-time molecular
// dynamics simulation does not count as an external provider, because it is
// part of MolecularRenderer.
public protocol MRStaticAtomProvider {
  var atoms: [MRAtom] { get }
}

// This must be set before adding any atoms via 'StaticAtomProvider'.
public protocol MRStaticStyleProvider {
  // Return all data in meters and Float32. The receiver will then range-reduce
  // to nanometers and cast to Float16.
  var radii: [Float] { get }
  
  // RGB color for each atom, ranging from 0 to 1 for each component.
  var colors: [SIMD3<Float>] { get }
  
  // Intensity of the camera-centered light for Blinn-Phong shading.
  var lightPower: Float { get }
  
  // The range of atomic numbers (inclusive). Anything outside this range uses
  // value in `radii` at index 0 and a black/magenta checkerboard pattern. The
  // range's start index must always be 1.
  //
  // TODO: Use this range instead of hard-coding the number 36 into the parsers.
  var atomicNumbers: ClosedRange<Int> { get }
}


