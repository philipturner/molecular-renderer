//
//  Vector.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

// Used for cutting hexagonal lattices.
public let a = Vector<Hexagonal>(x: .nan, y: .nan, z: .nan)
public let b = Vector<Hexagonal>(x: .nan, y: .nan, z: .nan)
public let c = Vector<Hexagonal>(x: .nan, y: .nan, z: .nan)

// Used for cutting cubic lattices and defining the positions of objects.
public let x = Vector<Cubic>(x: 1, y: 0, z: 0)
public let y = Vector<Cubic>(x: 0, y: 1, z: 0)
public let z = Vector<Cubic>(x: 0, y: 0, z: 1)

public struct Vector<T: Basis> {
  // This is a hack for right now, until we find something better for
  // lonsdaleite. For example, normalizing in a non-orthogonal basis would be
  // detrimental for rotations.
  var simdValue: SIMD3<Float> = .zero
  
  internal init(x: Float, y: Float, z: Float) {
    self.simdValue = SIMD3(x, y, z)
  }
  
  internal init(_ simdValue: SIMD3<Float>) {
    self.simdValue = simdValue
  }
  
  public static prefix func + (rhs: Vector<T>) -> Vector<T> {
    Vector(rhs.simdValue)
  }
  
  public static prefix func - (rhs: Vector<T>) -> Vector<T> {
    Vector(-rhs.simdValue)
  }
  
  public static func * (lhs: Float, rhs: Vector<T>) -> Vector<T> {
    Vector(lhs * rhs.simdValue)
  }
  
  public static func * (lhs: Vector<T>, rhs: Float) -> Vector<T> {
    Vector(lhs.simdValue * rhs)
  }
  
  public static func + (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    Vector(lhs.simdValue + rhs.simdValue)
  }
  
  public static func - (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    Vector(lhs.simdValue - rhs.simdValue)
  }
}
