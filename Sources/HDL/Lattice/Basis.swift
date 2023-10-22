//
//  Basis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public protocol Basis {
  static var h: Vector<Self> { get }
  static var k: Vector<Self> { get }
  static var l: Vector<Self> { get }
}

/// Used for cutting cubic lattices.
public struct Cubic: Basis {
  public static let h = Vector<Self>(x: 1, y: 0, z: 0)
  public static let k = Vector<Self>(x: 0, y: 1, z: 0)
  public static let l = Vector<Self>(x: 0, y: 0, z: 1)
}

/// Used for cutting hexagonal lattices.
public struct Hexagonal: Basis {
  public static let h = Vector<Self>(x: 1, y: 0, z: 0)
  public static let k = Vector<Self>(x: -0.5, y: 0.86602540378, z: 0)
  public static let l = Vector<Self>(x: 0, y: 0, z: 1)
}
