//
//  Bond.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

public enum Bond: RawRepresentable {
  case single
  case double
  case triple
  case fractional(Float)
  
  @inlinable @inline(__always)
  public init(rawValue: Float) {
    switch rawValue {
    case 1: self = .single
    case 2: self = .double
    case 3: self = .triple
    default:
      self = .fractional(rawValue)
    }
  }
  
  @inlinable @inline(__always)
  public var rawValue: Float {
    switch self {
    case .single: return 1
    case .double: return 2
    case .triple: return 3
    case .fractional(let bondOrder):
      return bondOrder
    }
  }
}
