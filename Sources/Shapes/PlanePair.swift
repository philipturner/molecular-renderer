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
  init<T>(_ reflected: Vector<T>, _ closure: () -> Vector<T>)
}

public struct Ridge {
  @discardableResult
  public init<T>(_ reflected: Vector<T>, _ closure: () -> Vector<T>) {
    fatalError("Not implemented.")
  }
}

public struct Valley {
  @discardableResult
  public init<T>(_ reflected: Vector<T>, _ closure: () -> Vector<T>) {
    fatalError("Not implemented.")
  }
}
