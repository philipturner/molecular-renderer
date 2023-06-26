//
//  OpenMM_Object.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

public class OpenMM_Object {
  public var pointer: OpaquePointer
  internal var _retain: Bool
  
  /// This initializer always takes ownership of the pointer.
  public init() {
    fatalError("\(#function) not implemented.")
  }
  
  /// This initializer does not take ownership of the pointer.
  public init(_ pointer: OpaquePointer?) {
    guard let pointer else {
      fatalError("OpenMM object pointer was null.")
    }
    self.pointer = pointer
    self._retain = false
  }
  
  /// Call this to take ownership of the object.
  public func retain() {
    guard _retain == false else {
      fatalError("Cannot have two owners at once.")
    }
    self._retain = true
  }
  
  /// Call this when transferring ownership to OpenMM API that will destroy it.
  public func transfer() {
    guard _retain else {
      fatalError("Did not have ownership; cannot transfer ownership to OpenMM.")
    }
    _retain = false
  }
  
  /// Every subclass must declare a unique override to this function, including
  /// subclasses of subclasses.
  public class func destroy(_ pointer: OpaquePointer) {
    fatalError("\(#function) not implemented.")
  }
  
  deinit {
    if _retain {
      Self.destroy(pointer)
    }
  }
}
