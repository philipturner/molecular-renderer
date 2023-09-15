//
//  Axis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public let a = Axis<Hexagonal>()
public let b = Axis<Hexagonal>()
public let c = Axis<Hexagonal>()
public let x = Axis<Cubic>()
public let y = Axis<Cubic>()
public let z = Axis<Cubic>()

public struct Axis<T: Basis> {
  internal init(/*arguments*/) {
    
  }
  
  public static prefix func + (rhs: Axis<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static prefix func - (rhs: Axis<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func * (lhs: Float, rhs: Axis<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func * (lhs: Axis<T>, rhs: Float) -> Vector<T> {
    fatalError("Not implemented.")
  }
}

public struct Vector<T: Basis> {
  public static prefix func + (rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static prefix func - (rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func + (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func - (lhs: Vector<T>, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func + (lhs: Axis<T>, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func + (lhs: Vector<T>, rhs: Axis<T>) -> Vector<T> {
    rhs + lhs
  }
  
  public static func - (lhs: Axis<T>, rhs: Vector<T>) -> Vector<T> {
    fatalError("Not implemented.")
  }
  
  public static func - (lhs: Vector<T>, rhs: Axis<T>) -> Vector<T> {
    -rhs + lhs
  }
}
