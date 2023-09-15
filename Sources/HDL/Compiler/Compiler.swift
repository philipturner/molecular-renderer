//
//  Compiler.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import QuaternionModule

// MARK: - Environment Objects

private class Compiler {
  public let global: Compiler = Compiler()
  
  public init() {
    // Resets the scene after the popping the stack of the outermost
    // 'Solid' scope.
  }
  
  /// Unstable API; do not use this function.
  public func _makeAtoms() -> [(origin: SIMD3<Float>, element: UInt8)] {
    return []
  }
  
  /// Unstable API; do not use this function.
  public func _reset() {
    
  }
}

// MARK: - Hacked Together Internal Representation

// This will be replaced with a more optimized representation that supports both
// diamond and lonsdaleite.

fileprivate func normalize(_ x: SIMD3<Float>) -> SIMD3<Float> {
  let length = (x * x).sum().squareRoot()
  return length == 0 ? .zero : (x / length)
}

fileprivate struct _Plane {
  var origin: SIMD3<Float>
  var normal: SIMD3<Float>
  
  init(origin: SIMD3<Float>, normal: SIMD3<Float>) {
    self.origin = origin
    self.normal = normal
  }
  
  init(_ latticeOrigin: SIMD3<Int>, normal: SIMD3<Float>) {
    self.origin = SIMD3(latticeOrigin) + 1e-2 * normalize(normal)
    self.normal = normalize(normal)
  }
  
  init(_ latticeOrigin: SIMD3<Float>, normal: SIMD3<Float>) {
    self.origin = SIMD3(latticeOrigin) + 1e-2 * normalize(normal)
    self.normal = normalize(normal)
  }
}

fileprivate struct Cell {
  // Local coordinates within the cell, containing atoms that haven't been
  // removed yet. References to atoms may be duplicated across cells.
  var atoms: [SIMD3<Float>] = []
  
  var offset: SIMD3<Int>
  
  init() {
    self.offset = .zero
    
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
  
  // Atom-plane intersection function. Avoid planes that perfectly align
  // with the crystal lattice, as the results of intersection functions may
  // be unpredictable.
  mutating func cleave(planes: [_Plane]) {
    atoms = atoms.compactMap {
      let atomOrigin = $0 + SIMD3<Float>(self.offset)
      
      var allIntersectionsPassed = true
      for plane in planes {
        let delta = atomOrigin - plane.origin
        let dotProduct = (delta * plane.normal).sum()
        if abs(dotProduct) < 1e-8 {
          fatalError("Cleaved along a perfect plane of atoms.")
        }
        if dotProduct < 0 {
          allIntersectionsPassed = false
        }
      }
      
      if allIntersectionsPassed {
        return nil
      } else {
        return $0
      }
    }
  }
  
  func cleaved(planes: [_Plane]) -> Cell {
    var copy = self
    copy.cleave(planes: planes)
    return copy
  }
  
  mutating func translate(offset: SIMD3<Int>) {
    self.offset &+= offset
  }
  
  func translated(offset: SIMD3<Int>) -> Cell {
    var copy = self
    copy.translate(offset: offset)
    return copy
  }
}

fileprivate func makeBaseLattice(
  width: Int, height: Int, depth: Int
) -> [Cell] {
  var output: [Cell] = []
  let baseCell = Cell()
  for i in 0..<width {
    for j in 0..<height {
      for k in 0..<depth {
        let offset = SIMD3(i, j, k)
        output.append(baseCell.translated(offset: offset))
      }
    }
  }
  return output
}

fileprivate func generateAtoms(
  _ latticePoints: [SIMD3<Float>]
) -> [(origin: SIMD3<Float>, element: UInt8)] {
  var hashMap: [SIMD3<Float>: Bool] = [:]
  for point in latticePoints {
    hashMap[point] = true
  }
  let allPoints = Array(hashMap.keys)
  return allPoints.map {
    (origin: $0 * 0.357, element: 6)
  }
}
