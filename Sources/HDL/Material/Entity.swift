//
//  Entity.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 10/22/23.
//

import Foundation

/// Either an atom or a connector.
public struct Entity {
  public var storage: SIMD4<Float>
  
  public var position: SIMD3<Float> {
    get {
      SIMD3(storage.x, storage.y, storage.z)
    }
    set {
      storage = SIMD4(newValue, storage.w)
    }
  }
  
  public var type: EntityType {
    get {
      fatalError()
    }
  }
  
}

public enum EntityType {
  case atom(UInt8)
  case bond(Float)
  case empty
}
