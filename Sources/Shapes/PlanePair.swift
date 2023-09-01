//
//  PlanePair.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

import HDL

// Share some common functionality between the two shapes.

public protocol PlanePair {
  @discardableResult
  init<T>(_ reflected: Axis<T>, _ closure: () -> Direction<T>)
  
  @discardableResult
  init<T>(_ reflected: Direction<T>, _ closure: () -> Direction<T>)
}

public struct Ridge {
  @discardableResult
  public init<T>(_ reflected: Axis<T>, _ closure: () -> Direction<T>) {
    fatalError("Not implemented.")
  }
  
  @discardableResult
  public init<T>(_ reflected: Direction<T>, _ closure: () -> Direction<T>) {
    fatalError("Not implemented.")
  }
}

public struct Valley {
  @discardableResult
  public init<T>(_ reflected: Axis<T>, _ closure: () -> Direction<T>) {
    fatalError("Not implemented.")
  }
  
  @discardableResult
  public init<T>(_ reflected: Direction<T>, _ closure: () -> Direction<T>) {
    fatalError("Not implemented.")
  }
}
