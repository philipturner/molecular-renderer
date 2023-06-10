//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Metal
import simd

// TODO: Rename this file to "Atom".

struct AtomStatistics {
  private var data: SIMD4<Float16>
  
  init(color: SIMD3<Float16>, radius: Float16) {
    self.data = SIMD4(color, radius)
  }
}

// This is a quick API hack to get the code refactored, but we need a more
// well thought-out solution in the long run. Ideally, recycle the
// 'AtomStatistics' paradigm from the GPU and use it for the CPU.
//
// TODO: In the C API, create a function that fills in the radii and flags of a
// massive batch of atoms.
struct GlobalStyleProvider {
  static let global = Self()
  
  var atomRadii: [Float16]
  
  var atomColors: [SIMD3<Float16>]
  
  var lightPower: Float16
  
  var atomicNumbers: ClosedRange<UInt8>
  
  init() {
    let provider = ExampleStyles.QuteMolDefault()
    self.atomRadii = provider.radii.map(Float16.init)
    self.atomColors = provider.colors.map(SIMD3.init)
    self.lightPower = Float16(provider.lightPower)
    
    let lowerBound = UInt8(provider.atomicNumbers.lowerBound)
    let upperBound = UInt8(provider.atomicNumbers.upperBound)
    self.atomicNumbers = lowerBound...upperBound
  }
}

struct BoundingBox {
  var min: MTLPackedFloat3
  var max: MTLPackedFloat3
}

// Stores the origin, radius squared, and atom type.
struct Atom: Equatable {
  // Position in nm.
  var x: Float
  var y: Float
  var z: Float
  
  // Radius in nm.
  var radiusSquared: Float16
  
  // Atomic number.
  var element: UInt8
  
  // Flags to modify how the atom is rendered.
  var flags: UInt8
  
  init(origin: SIMD3<Float>, element: UInt8, flags: UInt8 = 0) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = element
    self.flags = flags
    
    let radius = GlobalStyleProvider.global.atomRadii[Int(element)]
    self.radiusSquared = radius * radius
  }
  
  var origin: SIMD3<Float> {
    get { SIMD3(x, y, z) }
    set {
      x = newValue.x
      y = newValue.y
      z = newValue.z
    }
  }
  
  var radius: Float16 {
    GlobalStyleProvider.global.atomRadii[Int(element)]
  }
  
  var color: SIMD3<Float16> {
    GlobalStyleProvider.global.atomColors[Int(element)]
  }
  
  var boundingBox: BoundingBox {
    let min = origin - Float(radius)
    let max = origin + Float(radius)
    return BoundingBox(
      min: MTLPackedFloat3Make(min.x, min.y, min.z),
      max: MTLPackedFloat3Make(max.x, max.y, max.z))
  }
}

// MARK: - Universal Forcefield Statistics

class AtomicMasses {
  // Mass of each element on the periodic table, in kg.
  private var elements: Vector<Double>
  
  init() {
    elements = .init(repeating: 0, count: 119, alignment: 1)
    
    let amuToGrams = 1 / Double(6.022e23)
    let amuToKg = amuToGrams / 1000
    elements.setElement(4.002602 * amuToKg, index: 2)
    elements.setElement(20.1797 * amuToKg, index: 10)
    elements.setElement(39.948 * amuToKg, index: 18)
    elements.setElement(83.798 * amuToKg, index: 36)
  }
  
  @inline(__always)
  func getMass(atomicNumber: UInt8) -> Double {
    self.elements.getElement(index: Int(atomicNumber))
  }
}
