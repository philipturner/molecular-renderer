//
//  Bond.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

public enum Bond: RawRepresentable {
  /// A bond with order 1.
  case sigma
  
  /// A bond with variable order, determined using quantum mechanics.
  case pi
  
  @inlinable @inline(__always)
  public init(rawValue: Float) {
    switch rawValue {
    case 1: self = .sigma
    case 2: self = .pi
    default:
      fatalError("Invalid raw value for bond: \(rawValue)")
    }
  }
  
  @inlinable @inline(__always)
  public var rawValue: Float {
    switch self {
    case .sigma: return 1
    case .pi: return 2
    }
  }
}
