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
  // TODO: Remove this from the atom provider, and handle the switching of light
  // powers in the application code.
  var lightPower: Float { get }
  
  // The range of atomic numbers (inclusive). Anything outside this range uses
  // the value in `radii` at index 0 and a black/magenta checkerboard pattern.
  // The range's start index must always be 1.
  var atomicNumbers: ClosedRange<Int> { get }
}

// TODO: Create a DynamicAtomProvider API. The structure has to be different
// than MRStaticAtomProvider, because it may be loading data in real-time. We
// can't expect the data to materialize when we access the object every frame.
//
// Rather, we create two functions. The first prepared the data, either by
// creating GPU commands for molecular simulation, or issuing a Metal IO command
// buffer. The second function is called 3 frames later, and expects the data to
// be materialized. We will need to enter a monotonically increasing frame ID to
// incorporate time into the arguments.
//
// Another challenge is deciding how to handle frame stutters, which could cause
// a 3-frame freeze if we did it the naive way.
