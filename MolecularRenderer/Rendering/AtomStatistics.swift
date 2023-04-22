//
//  Geometry.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 4/6/23.
//

import Metal
import simd

let atomRadii: [Float16] = [
  0, // 0
  0.25, // 1
  0, // 2
  0, // 3
  0, // 4
  0, // 5
  0.40, // 6
]

let atomColors: [SIMD3<Float16>] = [
  SIMD3(repeating: 0), // 0
  SIMD3(0.900, 0.900, 0.900), // 1
  SIMD3(repeating: 0), // 2
  SIMD3(repeating: 0), // 3
  SIMD3(repeating: 0), // 4
  SIMD3(repeating: 0), // 5
  SIMD3(0.300, 0.300, 0.300), // 6
]

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


