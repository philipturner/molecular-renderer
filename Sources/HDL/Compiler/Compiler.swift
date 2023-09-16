//
//  Compiler.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 8/28/23.
//

import QuaternionModule

// MARK: - Environment Objects

public class Compiler {
  static let global: Compiler = Compiler()
  
  // For editing a lattice.
  private var stack: Stack?
  private var willUseLattice: Bool = false
  private var didSetMaterial: Bool = false
  
  // For combining multiple lattices or solids into a solid.
  private var solidCenters: [SIMD3<Float>]?
  private var solidOrigin: SIMD3<Float>?
  private var willUseSolid: Bool = false
  
  init() {
    // Resets the scene after the popping the stack of the outermost
    // 'Solid' scope.
  }
  
  /// Unstable API; do not use this function.
  public func _makeKeyFrames() {
    // Return key frames for animating the geometry compilation.
    // TODO: Method to track keyframes across the different objects. They only
    // track operations performed, not the evolution of the objects' data.
  }
}

extension Compiler {
  func reset() {
    stack = nil
    willUseLattice = false
    didSetMaterial = false
    
    solidCenters = nil
    solidOrigin = nil
    willUseSolid = false
  }
  
  func assertReset() {
    precondition(stack == nil)
    precondition(willUseLattice == false)
    precondition(didSetMaterial == false)
    
    precondition(solidCenters == nil)
    precondition(solidOrigin == nil)
    precondition(willUseSolid == false)
  }
}

extension Compiler {
  private func assertLattice() {
    precondition(willUseLattice && !willUseSolid)
  }
  
  private func assertBoundsSet() {
    assertLattice()
    precondition(didSetMaterial)
    precondition(stack != nil)
  }
  
  func startLattice<T: Basis>(type: T.Type) {
    precondition(T.self == Cubic.self, "Unsupported basis.")
    assertReset()
    willUseLattice = true
  }
  
  func endLattice<T: Basis>(type: T.Type) -> [SIMD3<Float>] {
    precondition(T.self == Cubic.self, "Unsupported basis.")
    assertLattice()
    defer { reset() }
    
    if let stack {
      return stack.result.makeCenters()
    } else {
      return []
    }
  }
  
  func setMaterial(_ elements: [Element]) {
    assertLattice()
    precondition(didSetMaterial == false)
    precondition(elements == [.carbon])
  }
  
  func setBounds(_ bounds: SIMD3<Int32>) {
    assertLattice()
    precondition(didSetMaterial)
    precondition(stack == nil)
    
    // For now, require the bounds to be greater than zero. Eventually, we may
    // permit bounds below zero that just shift the origin (or use a shifted
    // origin, but the bounds are positive, etc).
    precondition(all(bounds .> 0))
    stack = Stack(dimensions: bounds)
  }
  
  func startVolume() {
    assertLattice()
  }
  
  func endVolume() {
    assertLattice()
  }
}

extension Compiler {
  private func assertSolid() {
    precondition(willUseSolid && !willUseLattice)
  }
  
  func startSolid() {
    assertReset()
  }
  
  func endSolid() -> [SIMD3<Float>] {
    assertSolid()
    defer { reset() }
    
    if let solidCenters {
      return solidCenters
    } else {
      return []
    }
  }
  
  func startCopy() {
    assertSolid()
  }
  
  func endCopy() {
    assertSolid()
  }
}

//fileprivate func generateAtoms(
//  _ latticePoints: [SIMD3<Float>]
//) -> [(origin: SIMD3<Float>, element: UInt8)] {
//  var hashMap: [SIMD3<Float>: Bool] = [:]
//  for point in latticePoints {
//    hashMap[point] = true
//  }
//  let allPoints = Array(hashMap.keys)
//  return allPoints.map {
//    (origin: $0 * 0.357, element: 6)
//  }
//}
