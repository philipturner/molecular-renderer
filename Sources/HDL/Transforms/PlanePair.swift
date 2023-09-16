//
//  PlanePair.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

/// Unions of infinite planes for extruding slanted and curved surfaces.
public protocol PlanePair {
  /// Initialize a type conforming to the plane pair protocol.
  /// - Parameter reflected: The vector normal to the first plane.
  /// - Parameter closure: The vector to reflect the first plane's normal
  ///   across, when generating the second plane.
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
