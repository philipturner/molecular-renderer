//
//  Basis.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 9/1/23.
//

public protocol Basis { }

protocol _Basis: Basis {
  associatedtype Grid: LatticeGrid
}

public struct Cubic: _Basis {
  typealias Grid = CubicGrid
}

public struct Hexagonal: _Basis {
  typealias Grid = HexagonalGrid
}
