//
//  Vector.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public struct Vector<T: Basis> {
  // Normalizing in a non-orthogonal basis would be detrimental for rotations.
  // This doesn't need an orthonormal basis; it only needs to satisfy the
  // requirements for a vector space:
  // - s(A + B) = sA + sB
  var simdValue: SIMD3<Float> = .zero
  
  internal init(x: Float, y: Float, z: Float) {
    self.simdValue = SIMD3(x, y, z)
  }
  
  internal init(simdValue: SIMD3<Float>) {
    self.simdValue = simdValue
  }
  
  public static prefix func + (rhs: Vector<T>) -> Vector<T> {
    Vector(simdValue: rhs.simdValue)
  }
  
  public static prefix func - (rhs: Vector<T>) -> Vector<T> {
    Vector(simdValue: -rhs.simdValue)
  }
  
  public static func * (lhs: Float, rhs: Vector<T>) -> Vector<T> {
    Vector(simdValue: lhs * rhs.simdValue)
  }
  
  public static func * (lhs: Vector<T>, rhs: Float) -> Vector<T> {
    Vector(simdValue: lhs.simdValue * rhs)
  }
  
  public static func + (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    Vector(simdValue: lhs.simdValue + rhs.simdValue)
  }
  
  public static func - (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    Vector(simdValue: lhs.simdValue - rhs.simdValue)
  }
}
