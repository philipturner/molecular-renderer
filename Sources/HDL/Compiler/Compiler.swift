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
  
  // TODO: Track the lattice type, ensure all entered vectors are of the correct
  // type. Then, support the correct API for lattices composed of multiple
  // sub-lattices. To enable combining of two crystal lattices, one may need to
  // track the lower left corner of the bounds.
  //
  // The current solution is to crash with `fatalError("Not implemented")` for
  // `Hexagonal` vectors. `Amorphous` vectors are suppressed because the
  // necessary basis vectors (x, y, z) aren't exposed to the public API.
  
  // For combining multiple lattices or solids into a solid.
  private var solidStack: SolidStack?
  private var willUseSolid: Bool = false
  private var didSetAffine: Bool = false
  
  private var keyFrames: [AnimationKeyFrame] = []
  
  init() {
    
  }
  
  /// Unstable API; do not use this function.
  public func _getKeyFrames() -> [AnimationKeyFrame] {
    return keyFrames
  }
  
  /// Unstable API; do not use this function.
  public func _resetKeyFrames() {
    keyFrames = []
  }
}

extension Compiler {
  func reset() {
    stack = nil
    willUseLattice = false
    didSetMaterial = false
    
    solidStack = nil
    willUseSolid = false
    didSetAffine = false
  }
  
  func assertReset() {
    precondition(stack == nil)
    precondition(willUseLattice == false)
    precondition(didSetMaterial == false)
    
    precondition(solidStack == nil)
    precondition(willUseSolid == false)
    precondition(didSetAffine == false)
  }
  
  func moveOrigin(_ delta: SIMD3<Float>) {
    if willUseLattice {
      assertBoundsSet()
      stack!.applyOrigin(delta: delta)
    } else if willUseSolid {
      assertSolid()
      solidStack!.applyOrigin(delta: delta)
    } else {
      fatalError()
    }
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
      return stack.result.makeCenters().map { $0 * 1 }
    } else {
      return []
    }
  }
  
  func setMaterial(_ elements: [Element]) {
    assertLattice()
    precondition(didSetMaterial == false)
    precondition(elements == [.carbon])
    didSetMaterial = true
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
    assertBoundsSet()
    stack!.pushOrigin()
    stack!.pushVolume()
  }
  
  func endVolume() {
    assertBoundsSet()
    stack!.popOrigin()
    stack!.popVolume()
  }
  
  func startConvex() {
    assertBoundsSet()
    stack!.pushOrigin()
    stack!.pushPlaneType(.convex)
  }
  
  func endConvex() {
    assertBoundsSet()
    stack!.popOrigin()
    stack!.popPlaneType()
  }
  
  func startConcave() {
    assertBoundsSet()
    stack!.pushOrigin()
    stack!.pushPlaneType(.concave)
  }
  
  func endConcave() {
    assertBoundsSet()
    stack!.popOrigin()
    stack!.popPlaneType()
  }
  
  func addPlane(_ vector: SIMD3<Float>) {
    assertBoundsSet()
    stack!.applyPlane(normal: vector)
  }
  
  func performCut() {
    assertBoundsSet()
    stack!.cut()
  }
}

extension Compiler {
  private func assertSolid() {
    precondition(willUseSolid && !willUseLattice)
  }
  
  private func assertAffine() {
    assertSolid()
    precondition(didSetAffine)
  }
  
  func startSolid() {
    assertReset()
    willUseSolid = true
    solidStack = SolidStack()
  }
  
  func endSolid() -> [SIMD3<Float>] {
    assertSolid()
    defer { reset() }
    
    if let solidStack {
      return solidStack.centers.keys.map { $0 }
    } else {
      return []
    }
  }
  
  func startAffine() {
    assertSolid()
    precondition(!didSetAffine)
    didSetAffine = true
    solidStack!.pushOrigin()
    solidStack!.startAffine()
  }
  
  func endAffine() {
    assertAffine()
    didSetAffine = false
    solidStack!.popOrigin()
    solidStack!.endAffine()
  }
  
  func performCopy(_ centers: [SIMD3<Float>]) {
    assertSolid()
    solidStack!.addCenters(centers, affine: didSetAffine)
  }
  
  func performReflect(_ vector: SIMD3<Float>) {
    assertAffine()
    solidStack!.applyReflect(vector)
  }
  
  func performRotate(_ vector: SIMD3<Float>) {
    assertAffine()
    solidStack!.applyRotate(vector)
  }
  
  func performTranslate(_ vector: SIMD3<Float>) {
    assertAffine()
    solidStack!.applyTranslate(vector)
  }
}
