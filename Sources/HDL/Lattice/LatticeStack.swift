//
//  Stack.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 9/15/23.
//

import Foundation

fileprivate func normalize(_ x: SIMD3<Float>) -> SIMD3<Float> {
  let length = (x * x).sum().squareRoot()
  return length == 0 ? .zero : (x / length)
}

fileprivate func dot(_ x: SIMD3<Float>, _ y: SIMD3<Float>) -> Float {
  return (x * y).sum()
}

fileprivate struct _Plane {
  var origin: SIMD3<Float>
  var normal: SIMD3<Float>
  
  init(origin: SIMD3<Float>, normal: SIMD3<Float>) {
    self.normal = normalize(normal)
    self.origin = origin + 0.01 * self.normal
  }
}

fileprivate struct SignedDistanceField {
  var outerDimensions: SIMD3<Int32>
  var data: [Float]
  
  init(innerDimensions: SIMD3<Int32>, plane: _Plane) {
    self.outerDimensions = innerDimensions &+ 1
    self.data = Array(repeating: 0, count: Int(
      outerDimensions[0] * outerDimensions[1] * outerDimensions[2]))
    
    for k in 0..<outerDimensions.z {
      for j in 0..<outerDimensions.y {
        for i in 0..<outerDimensions.x {
          let address =
          k &* outerDimensions.y &* outerDimensions.x &+
          j &* outerDimensions.x &+
          i
          
          let position = SIMD3<Float>(SIMD3(i, j, k))
          let delta = position - plane.origin
          let dotProduct = (delta * plane.normal).sum()
          data[Int(address)] = dotProduct
        }
      }
    }
  }
}

fileprivate struct ReferenceCell {
  static let global = ReferenceCell()
  
  var atoms: [SIMD3<Float>] = []
  
  init() {
    for i in 0..<2 {
      for j in 0..<2 {
        for k in 0..<2 {
          if i ^ j ^ k == 0 {
            var position = SIMD3(Float(i), Float(j), Float(k))
            atoms.append(position)
            
            for axis in 0..<3 {
              if position[axis] == 0 {
                position[axis] = 0.25
              } else {
                position[axis] = 0.75
              }
            }
            atoms.append(position)
          }
        }
      }
    }
    
    for axis in 0..<3 {
      var position = SIMD3<Float>(repeating: 0.5)
      position[axis] = 0
      atoms.append(position)
      
      position[axis] = 1
      atoms.append(position)
    }
  }
  
  func intersect(_ plane: _Plane) -> UInt64 {
    var output: SIMD16<UInt64> = .zero
    for i in 0..<14 {
      let atom = self.atoms[i]
      let delta = atom - plane.origin
      let dotProduct = (delta * plane.normal).sum()
      output[i] = dotProduct < 0 ? 1 << i : 0
    }
    return output.wrappedSum()
  }
}

struct Mask {
  var dimensions: SIMD3<Int32>
  var data: [UInt64]
  
  init(dimensions: SIMD3<Int32>) {
    self.dimensions = dimensions
    self.data = Array(repeating: 0b0011_1111_1111_1111, count: Int(
      dimensions[0] * dimensions[1] * dimensions[2]))
  }
  
  // Use this to append a plane to the mask.
  fileprivate mutating func apply(plane: _Plane) {
    let field = SignedDistanceField(
      innerDimensions: dimensions, plane: plane)
    for k in 0..<dimensions.z {
      for j in 0..<dimensions.y {
        for i in 0..<dimensions.x {
          let start = SIMD3(i, j, k)
          var gather: SIMD8<Float> = .zero
          
          let field_xy = field.outerDimensions.y &* field.outerDimensions.x
          for a in 0..<Int32(2) {
            for b in 0..<Int32(2) {
              for c in 0..<Int32(2) {
                let lane = a * 4 + b * 2 + c
                let coords = start &+ SIMD3(a, b, c)
                let address =
                coords.z &* field_xy &+
                coords.y &* field.outerDimensions.x &+ coords.x
                gather[Int(lane)] = field.data[Int(address)]
              }
            }
          }
          
          let negative = any(gather .< 0)
          let positive = any(gather .> 0)
          let address =
          start.z &* dimensions.y &* dimensions.x &+
          start.y &* dimensions.x &+ start.x
          if (positive && negative) {
            var copy = plane
            copy.origin -= SIMD3<Float>(start)
            data[Int(address)] &= ReferenceCell.global.intersect(copy)
          } else if positive {
            data[Int(address)] = 0
          }
        }
      }
    }
  }
  
  // Perform logical AND on the zeroed out cells.
  mutating func and(mask: Mask) {
    guard all(dimensions .== mask.dimensions) else {
      fatalError("Masks had different dimensions.")
    }
    for i in 0..<data.count {
      // Truth Table
      //
      // x | y | f
      // --|---|---
      // 0 | 0 | 0
      // 0 | 1 | 1
      // 1 | 0 | 1
      // 1 | 1 | 1
      data[i] = ~(~data[i] & ~mask.data[i])
    }
  }
  
  // Perform logical OR on the zeroed out cells.
  mutating func or(mask: Mask) {
    guard all(dimensions .== mask.dimensions) else {
      fatalError("Masks had different dimensions.")
    }
    for i in 0..<data.count {
      // Truth Table
      //
      // x | y | f
      // --|---|---
      // 0 | 0 | 0
      // 0 | 1 | 0
      // 1 | 0 | 0
      // 1 | 1 | 1
      data[i] = ~(~data[i] | ~mask.data[i])
    }
  }
  
  // Use this to find which atoms to animate as moving away.
  mutating func not() {
    for i in 0..<data.count {
      data[i] = ~data[i]
    }
  }
  
  // Lattice-aligned centers of atoms.
  func makeCenters() -> [SIMD3<Float>] {
    let cell = ReferenceCell.global
    var centers: [SIMD3<Float>: Bool] = [:]
    
    for k in 0..<dimensions.z {
      for j in 0..<dimensions.y {
        for i in 0..<dimensions.x {
          let address =
          k &* dimensions.y &* dimensions.x &+
          j &* dimensions.x &+ i
          let cellMask = data[Int(address)]
          if cellMask == 0 { continue }
          
          let start = SIMD3<Float>(SIMD3(i, j, k))
          for i in 0..<14 where cellMask & (1 << i) != 0 {
            centers[start + cell.atoms[i]] = true
          }
        }
      }
    }
    return centers.keys.map { $0 }
  }
}

struct Stack {
  enum PlaneType {
    case concave
    case convex
    case volume
  }
  
  // The boundary of the grid.
  var dimensions: SIMD3<Int32>
  
  // TODO: Variable for offset of the grid's start from (0, 0, 0).
  
  // The result of all cuts in the grid. To be translated back into atoms when
  // the grid is finished.
  var result: Mask
  
  // Absolute origins at each level of the stack.
  var origins: [SIMD3<Float>] = []
  
  // Only the masks generated by the volume's planes. OR the zeroes of all these
  // masks to reduce.
  var volumeScopes: [Mask?] = []
  
  // Encapsulates operations occurring inside a `Convex` or `Concave`.
  var planeScopes: [Mask?] = []
  
  // Defines how to append planes to the latest mask.
  var types: [PlaneType] = []
  
  init(dimensions: SIMD3<Int32>) {
    self.dimensions = dimensions
    self.result = Mask(dimensions: dimensions)
    self.origins.append(.zero)
    self.volumeScopes.append(nil)
    self.types.append(.volume)
  }
  
  mutating func applyOrigin(delta: SIMD3<Float>) {
    origins[origins.count - 1] += delta
  }
  
  mutating func applyPlane(normal: SIMD3<Float>) {
    let plane = _Plane(origin: origins.last ?? .zero, normal: normal)
    var mask = Mask(dimensions: dimensions)
    mask.apply(plane: plane)
    applyMask(mask)
  }
  
  mutating func applyMask(_ mask: Mask) {
    if types.last! == .concave || types.last! == .convex,
       planeScopes[planeScopes.count - 1] == nil {
      planeScopes[planeScopes.count - 1] = mask
      return
    }
    
    switch types.last! {
    case .concave:
      planeScopes[planeScopes.count - 1]!.and(mask: mask)
    case .convex:
      planeScopes[planeScopes.count - 1]!.or(mask: mask)
    case .volume:
      if volumeScopes[volumeScopes.count - 1] == nil {
        volumeScopes[volumeScopes.count - 1] = mask
      } else {
        volumeScopes[volumeScopes.count - 1]!.or(mask: mask)
      }
    }
  }
  
  mutating func cut() {
    var sum: Mask?
    for scope in volumeScopes + planeScopes {
      if sum == nil {
        sum = scope
      } else if let scope {
        sum!.or(mask: scope)
      }
    }
    if let sum {
      result.or(mask: sum)
    }
  }
  
  mutating func pushOrigin() {
    origins.append(origins.last!)
  }
  
  mutating func popOrigin() {
    origins.removeLast()
  }
  
  mutating func pushVolume() {
    types.append(.volume)
    volumeScopes.append(nil)
  }
  
  mutating func popVolume() {
    types.removeLast()
    volumeScopes.removeLast()
  }
  
  mutating func pushPlaneType(_ type: PlaneType) {
    types.append(type)
    planeScopes.append(nil)
  }
  
  mutating func popPlaneType() {
    types.removeLast()
    if let mask = planeScopes.removeLast() {
      applyMask(mask)
    }
  }
}

struct SolidStack {
  // The atoms in the solid.
  var centers: [SIMD3<Float>: Bool] = [:]
  
  // Absolute origins at each level of the stack.
  var origins: [SIMD3<Float>] = []
  
  // Centers for the object currently being transformed.
  var affineCenters: [SIMD3<Float>: Bool]?
  
  init() {
    self.centers = [:]
    self.origins.append(.zero)
  }
  
  // This should instead store a (possibly duplicated) list of carbon centers,
  // which gets de-duplicated at the end of compilation. Make a common utility
  // shared between the solid stack and regular stack, which handles sorting of
  // atoms into an arbitrarily spaced grid.
  mutating func addCenters(_ centers: [SIMD3<Float>], affine: Bool) {
    if affine {
      precondition(affineCenters != nil)
      for center in centers {
        self.affineCenters![center] = true
      }
    } else {
      for center in centers {
        self.centers[center] = true
      }
    }
  }
  
  mutating func applyOrigin(delta: SIMD3<Float>) {
    origins[origins.count - 1] += delta
  }
  
  mutating func applyReflect(_ vector: SIMD3<Float>) {
    precondition(affineCenters != nil)
    let keys = affineCenters!.keys.map { $0 }
    affineCenters = [:]
    
    let origin = self.origins.last!
    let direction = normalize(vector)
    for key in keys {
      var delta = key - origin
      delta -= 2 * direction * dot(delta, direction)
      
      let original = delta + origin
      let position = (original * 4).rounded(.toNearestOrEven) / 4
      let difference = position - original
      if any((difference .> 0.01) .| (difference .< -0.01)) {
        fatalError("Did not reflect across a (100), (110), or (111) plane.")
      }
      
      affineCenters![origin + delta] = true
    }
  }
  
  mutating func applyRotate(_ vector: SIMD3<Float>) {
    precondition(affineCenters != nil)
    let keys = affineCenters!.keys.map { $0 }
    affineCenters = [:]
    
    let origin = self.origins.last!
    var mask: SIMD3<Int> = .zero
    for i in 0..<3 {
      mask[i] = (vector[i] == 0) ? 0 : 1
    }
    guard mask.wrappedSum() == 1 else {
      // Require that it's rotating around a perfect X, Y, or Z axis for now.
      fatalError("Did not rotate around a perfect X, Y, or Z axis.")
    }
    
    // Just take the sum of all lanes, as we assume only one is nonzero.
    let revolutions = vector.sum()
    let roundedRevolutions = (revolutions * 4).rounded(.toNearestOrEven) / 4
    if abs(roundedRevolutions - revolutions) > 0.01 {
      fatalError("Did not rotate by a multiple of 90 degrees.")
    }
    var rotationCount = Int(rint(roundedRevolutions * 4))
    rotationCount %= 4
    if rotationCount < 0 {
      rotationCount = 4 + rotationCount
    }
    precondition(rotationCount >= 0 && rotationCount < 4)
    
    var rotatedAxis1: Int
    var rotatedAxis2: Int
    switch mask {
    case SIMD3(1, 0, 0):
      rotatedAxis1 = 1
      rotatedAxis2 = 2
    case SIMD3(0, 1, 0):
      rotatedAxis1 = 2
      rotatedAxis2 = 0
    case SIMD3(0, 0, 1):
      rotatedAxis1 = 0
      rotatedAxis2 = 1
    default:
      fatalError("This should never happen.")
    }
    
    for key in keys {
      var delta = key - origin
      for _ in 0..<rotationCount {
        let oldCoord1 = delta[rotatedAxis1]
        let oldCoord2 = delta[rotatedAxis2]
        delta[rotatedAxis1] = -oldCoord2
        delta[rotatedAxis2] = oldCoord1
      }
      
      affineCenters![origin + delta] = true
    }
  }
  
  mutating func applyTranslate(_ vector: SIMD3<Float>) {
    precondition(affineCenters != nil)
    let keys = affineCenters!.keys.map { $0 }
    affineCenters = [:]
    
    for key in keys {
      affineCenters![key + vector] = true
    }
  }
  
  mutating func pushOrigin() {
    origins.append(origins.last!)
  }
  
  mutating func popOrigin() {
    origins.removeLast()
  }
  
  mutating func startAffine() {
    precondition(affineCenters == nil)
    affineCenters = [:]
  }
  
  mutating func endAffine() {
    precondition(affineCenters != nil)
    addCenters(affineCenters!.keys.map { $0 }, affine: false)
    affineCenters = nil
  }
}
