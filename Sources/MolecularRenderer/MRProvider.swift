//
//  MRProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation

// NOTE: These protocols cannot be part of the C API. Rather, create a C struct
// with pointers to lists. The Swift package will internally create an object
// conforming to `MR*Provider`, which wraps the data imported from C.

// A finite-state machine that changes state based on time.
public protocol MRAtomProvider {
  mutating func atoms(time: MRTimeContext) -> [MRAtom]
}

// C API: Each array must contain 250 elements, corresponding to Z=0-249. Unused
// array slots can be empty.
//
// Swift API: Each array must contain enough elements to correspond to the
// filled slots in `available`.
public protocol MRAtomStyleProvider {
  var styles: [MRAtomStyle] { get }
  var available: [Bool] { get }
}

// colors:
//   RGB color for each atom, ranging from 0 to 1 for each component.
// radii:
//   Enter all data in meters and Float32. They will be range-reduced to
//   nanometers and converted to Float16.
// available:
//   Whether each element has a style. Anything without a style uses `radii[0]`
//   and a black/magenta checkerboard pattern.
//
// TODO: C API using a function underscored on the Swift side, requires that you
// deallocate the return value.
//   @_cdecl("MRMakeAtomStyles")
public func MRMakeAtomStyles(
  colors: [SIMD3<Float>],
  radii: [Float],
  available: [Bool]
) -> [MRAtomStyle] {
#if arch(x86_64)
    let atomColors: [SIMD3<Float16>] = []
#else
    let atomColors = colors.map(SIMD3<Float16>.init)
#endif
    let atomRadii = radii.map { $0 * 1e9 }.map(Float16.init)
    
    precondition(available.count == 250)
    return available.indices.map { i in
      let index = available[i] ? i : 0
      return MRAtomStyle(color: atomColors[index], radius: atomRadii[index])
    }
}
