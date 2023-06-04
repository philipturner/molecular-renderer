//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Metal
import simd

// Bondi (1964) convention expanded to more elements in 2009. Hydrogen and
// lithium values are not lowered to (1.20 -> 1.10, 1.82 -> 1.81) because that
// makes ethylene look wierd.
// https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3658832
// Larger than QuteMol:
// https://github.com/zulman/qutemol/blob/master/src/AtomColor.cpp#L28
#if false
let atomRadii: [Float16] = [Float]([
  0.00, // 0
  1.20, // 1
  1.40, // 2
  
  1.82, // 3
  1.53, // 4
  1.92, // 5
  1.70, // 6
  1.55, // 7
  1.52, // 8
  1.47, // 9
  1.54, // 10
  
  2.27, // 11
  1.73, // 12
  1.84, // 13
  2.10, // 14
  1.80, // 15
  1.80, // 16
  1.75, // 17
  1.88, // 18
  
  0.00, // 19
  0.00, // 20
  0.00, // 21
  0.00, // 22
  0.00, // 23
  0.00, // 24
  0.00, // 25
  0.00, // 26
  0.00, // 27
  0.00, // 28
  0.00, // 29
  0.00, // 30
  0.00, // 31
  0.00, // 32
  0.00, // 33
  0.00, // 34
  0.00, // 35
  0.00, // 36
]).map { Float16($0 / 10) }

// Jmol color scheme:
// https://jmol.sourceforge.net/jscolors/#color_C
// Also used by QuteMol:
// https://github.com/zulman/qutemol/blob/master/src/AtomColor.cpp#L54
let atomColors: [SIMD3<Float16>] = [SIMD3<Float>]([
  SIMD3(  0,   0,   0), // 0
  SIMD3(255, 255, 255), // 1
  SIMD3(217, 255, 255), // 2
  
  SIMD3(204, 128, 255), // 3
  SIMD3(194, 255,   0), // 4
  SIMD3(255, 181, 181), // 5
  SIMD3(144, 144, 144), // 6
  SIMD3( 48,  80, 248), // 7
  SIMD3(255,  13,  13), // 8
  SIMD3(144, 224,  80), // 9
  SIMD3(179, 227, 245), // 10
  
  SIMD3(171,  92, 242), // 11
  SIMD3(138, 255,   0), // 12
  SIMD3(191, 166, 166), // 13
  SIMD3(240, 200, 160), // 14
  SIMD3(255, 128,   0), // 15
  SIMD3(255, 255,  48), // 16
  SIMD3( 31, 240,  31), // 17
  SIMD3(128, 209, 227), // 18
  
  SIMD3(143,  64, 212), // 19
  SIMD3( 61, 255,   0), // 20
  SIMD3(230, 230, 230), // 21
  SIMD3(191, 194, 199), // 22
  SIMD3(166, 166, 171), // 23
  SIMD3(138, 153, 199), // 24
  SIMD3(156, 122, 199), // 25
  SIMD3(224, 102,  51), // 26
  SIMD3(240, 144, 160), // 27
  SIMD3( 80, 208,  80), // 28
  SIMD3(200, 128,  51), // 29
  SIMD3(125, 128, 176), // 30
  SIMD3(194, 143, 143), // 31
  SIMD3(102, 143, 143), // 32
  SIMD3(189, 128, 227), // 33
  SIMD3(255, 161,   0), // 34
  SIMD3(166,  41,  41), // 35
  SIMD3( 92, 184, 209), // 36
]).map { SIMD3<Float16>($0 / Float(255)) }
#else
// Alternative parameters sourced from this ART file, which cover most of the
// periodic table:
// https://github.com/zulman/qutemol/blob/a7ca8add0683cd311cbcdbed5c7e49cb1681fb61/src/install/art_example.txt#L4
//
// The file also reappears here:
// https://github.com/zulman/qutemol/blob/a7ca8add0683cd311cbcdbed5c7e49cb1681fb61/src/sample/nanostuff.art#L4
let atomRadii: [Float16] = [Float]([
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
]).map { Float16($0 / 10) }

let atomColors: [SIMD3<Float16>] = [SIMD3<Float>]([
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
]).map { SIMD3<Float16>($0 / Float(255)) }
#endif

struct AtomStatistics {
  private var data: SIMD4<Float16>
  
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
  
  init(origin: SIMD3<Float>, element: UInt8, flags: UInt8 = 0) {
    self.x = origin.x
    self.y = origin.y
    self.z = origin.z
    self.element = element
    self.flags = flags
    
    let radius = atomRadii[Int(element)]
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
    atomRadii[Int(element)]
  }
  
  var color: SIMD3<Float16> {
    atomColors[Int(element)]
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
