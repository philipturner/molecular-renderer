//
//  Entity.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

import Foundation

// Rule for converting to an efficient layout in the crystal grid:

public enum EntityType: RawRepresentable {
  case atom(UInt8)
  case bond(Float)
  case empty
  
  @inlinable @inline(__always)
  public init(rawValue: Float) {
    if rawValue > 0 {
      self = .atom(UInt8(exactly: rawValue) ?? 0)
    } else if rawValue < 0 {
      self = .bond(-rawValue)
    } else {
      // NaN or zero
      self = .empty
    }
  }
  
  @inlinable @inline(__always)
  public var rawValue: Float {
    switch self {
    case .atom(let atomicNumber):
      return Float(atomicNumber)
    case .bond(let bondOrder):
      return Float(-bondOrder)
    case .empty:
      return 0
    }
  }
}

/// Either an atom or a connector.
public struct Entity {
  public var storage: SIMD4<Float>
  
  @inlinable @inline(__always)
  public var position: SIMD3<Float> {
    get {
      SIMD3(storage.x, storage.y, storage.z)
    }
    set {
      storage = SIMD4(newValue, storage.w)
    }
  }
  
  @inlinable @inline(__always)
  public var type: EntityType {
    get {
      EntityType(rawValue: storage.w)
    }
    set {
      storage.w = newValue.rawValue
    }
  }
  
  @inlinable @inline(__always)
  public init(storage: SIMD4<Float>) {
    self.storage = storage
  }
  
  @inlinable @inline(__always)
  public init(position: SIMD3<Float>, type: EntityType) {
    self.storage = SIMD4(position, type.rawValue)
  }
}

/// A block of entities for processing in parallel in a SIMD instruction.
struct EntityBlock {
  var x: SIMD8<Float>
  var y: SIMD8<Float>
  var z: SIMD8<Float>
  var w: SIMD8<Float>
}
