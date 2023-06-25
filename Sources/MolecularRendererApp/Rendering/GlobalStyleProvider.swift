//
//  GlobalStyleProvider.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation
import MolecularRenderer

// This is a quick API hack to get the code refactored, but we need a more
// well thought-out solution in the long run. Ideally, recycle the
// 'AtomStatistics' paradigm from the GPU and use it for the CPU.
//
// TODO: In the C API, create a function that accepts the origin and element ID
// of a massive batch of atoms, then initializes the 'MRAtom' structs.
//
// TODO: Transfer the above 'TODO' into the Swift package and delete this file.
//
//struct GlobalStyleProvider {
//  static let global = Self()
//  
//  var atomRadii: [Float16]
//  
//  var atomColors: [SIMD3<Float16>]
//  
//  var lightPower: Float16
//  
//  var atomicNumbers: ClosedRange<UInt8>
//  
//  var styles: [MRAtomStyle]
//  
//  init() {
//    let provider = ExampleStyles.NanoStuff()
//    self.atomRadii = provider.radii.map(Float16.init)
//    self.atomColors = provider.colors.map(SIMD3.init)
//    self.lightPower = Float16(provider.lightPower)
//    
//    let lowerBound = UInt8(provider.atomicNumbers.lowerBound)
//    let upperBound = UInt8(provider.atomicNumbers.upperBound)
//    self.atomicNumbers = lowerBound...upperBound
//    
//    self.styles = zip(atomColors, atomRadii).map {
//      MRAtomStyle(color: $0, radius: $1)
//    }
//  }
//}
