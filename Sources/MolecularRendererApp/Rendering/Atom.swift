//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Metal
import simd

// TODO: Prefix everything with 'MR' and move to the Swift package.

struct AtomStatistics {
  // TODO: Try making an inlined function in the C header, which unpacks the
  // data into the color and radius? Not sure the best way to approach this.
  //
  // TODO: Define each component separately and force an 8-byte alignment in the
  // Swift and Clang compilers.
  private var data: SIMD4<Float16>
  
  // Color in RGB color space.
  var color: SIMD3<Float16> { .init(data.x, data.y, data.z) }
  
  // Radius in nm. We don't know the actual radius to 11 bits of precision, so
  // Float16 is fine.
  var radius: Float16 { data.w }
  
  init(color: SIMD3<Float16>, radius: Float16) {
    self.data = SIMD4(color, radius)
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
  
  init(
    atomData: UnsafePointer<AtomStatistics>,
    origin: SIMD3<Float>,
    element: UInt8,
    flags: UInt8 = 0
  ) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = element
    self.flags = flags
    
    let radius = atomData[Int(element)].radius
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
  
  func getRadius(atomData: UnsafePointer<AtomStatistics>) -> Float16 {
    atomData[Int(element)].radius
  }
  
  func getColor(atomData: UnsafePointer<AtomStatistics>) -> SIMD3<Float16> {
    atomData[Int(element)].color
  }
  
  func getBoundingBox(atomData: UnsafePointer<AtomStatistics>) -> BoundingBox {
    let radius = getRadius(atomData: atomData)
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
