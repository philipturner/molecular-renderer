//
//  Vector.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

// TODO: Add another basis for representing vectors in `Solid`, once you break
// out of the lattice space.
public let a = Vector<Hexagonal>()
public let b = Vector<Hexagonal>()
public let c = Vector<Hexagonal>()
public let x = Vector<Cubic>()
public let y = Vector<Cubic>()
public let z = Vector<Cubic>()

public struct Vector<T: Basis> {
  internal init(/*arguments*/) {
    
  }
  
  public static prefix func + (rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static prefix func - (rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func * (lhs: Float, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func * (lhs: Vector<T>, rhs: Float) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func + (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func - (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
}
