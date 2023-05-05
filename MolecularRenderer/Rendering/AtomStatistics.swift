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
let atomRadii: [Float16] = [
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
].map { $0 / 10 }

// Jmol color scheme:
// https://jmol.sourceforge.net/jscolors/#color_C
// Also used by QuteMol:
// https://github.com/zulman/qutemol/blob/master/src/AtomColor.cpp#L54
let atomColors: [SIMD3<Float16>] = [
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
].map { $0 / 255 }

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
struct Atom {
  var x: Float
  var y: Float
  var z: Float
  var radiusSquared: Float16
  var element: UInt8
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


