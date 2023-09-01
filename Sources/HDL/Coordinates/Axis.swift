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
  
  public static prefix func + (rhs: Axis<T>) -> Direction<T> {
    fatalError("Not implemented.")
  }
  
  public static prefix func - (rhs: Axis<T>) -> Direction<T> {
    fatalError("Not implemented.")
  }
  
  public static func * (lhs: Float, rhs: Axis<T>) -> Position<T> {
    fatalError("Not implemented.")
  }
  
  public static func * (lhs: Axis<T>, rhs: Float) -> Position<T> {
    fatalError("Not implemented.")
  }
}

public struct Direction<T: Basis> {
  public static func ^ (lhs: Direction<T>, rhs: Direction<T>) -> Direction<T> {
    fatalError("Not implemented.")
  }
}

public struct Position<T: Basis> {
  public static func + (lhs: Position<T>, rhs: Position<T>) -> Position<T> {
    fatalError("Not implemented.")
  }
  
  public static func - (lhs: Position<T>, rhs: Position<T>) -> Position<T> {
    fatalError("Not implemented.")
  }
}
