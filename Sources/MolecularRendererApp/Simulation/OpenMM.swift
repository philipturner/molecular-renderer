//
//  OpenMM.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/10/23.
//

import Foundation
import OpenMM

// Use OpenMM for prototyping MD algorithms and developing the serialization
// format for MolecularRenderer.

func initOpenMM() {
  // Disable the nearest neighbor list because we run very small simulations.
  setenv("OPENMM_METAL_USE_NEIGHBOR_LIST", "0", 1)
  
  let directory = OpenMM_Platform.defaultPluginsDirectory!
  print("OpenMM plugins directory: \(directory)")
  
  let plugins = OpenMM_Platform.loadPlugins(directory: directory)!
  print("Found plugins!")
  
  let numPlugins = plugins.size
  print("Number of plugins: \(numPlugins)")
  
  for i in 0..<numPlugins {
    print("Plugin \(i + 1): \(plugins[i])")
  }
}

// MARK: - OpenMM Swift Bindings

// TODO: Extract this into a Swift module, rename the current "OpenMM" as
// "COpenMM", and call the wrappers the new "OpenMM".

class OpenMM_Object {
  var pointer: OpaquePointer
  internal var _retain: Bool
  
  /// This initializer always takes ownership of the pointer.
  init() {
    fatalError("\(#function) not implemented.")
  }
  
  /// This initializer does not take ownership of the pointer.
  init(_ pointer: OpaquePointer?) {
    guard let pointer else {
      fatalError("OpenMM object pointer was null.")
    }
    self.pointer = pointer
    self._retain = false
  }
  
  /// Call this to take ownership of the object.
  func retain() {
    guard _retain == false else {
      fatalError("Cannot have two owners at once.")
    }
    self._retain = true
  }
  
  /// Call this when transferring ownership to OpenMM API that will destroy it.
  func transfer() {
    guard _retain else {
      fatalError("Did not have ownership; cannot transfer ownership to OpenMM.")
    }
    _retain = false
  }
  
  class func destroy(_ pointer: OpaquePointer) {
    fatalError("\(#function) not implemented.")
  }
  
  deinit {
    if _retain {
      Self.destroy(pointer)
    }
  }
}

// MARK: - OpenMM Constants

// Probably need something like @_exported import OpenMM_PsPerFs

// MARK: - OpenMM Classes

class OpenMM_Force: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Force_destroy(pointer)
  }
}

class OpenMM_NonbondedForce: OpenMM_Force {
  override init() {
    guard let pointer = OpenMM_NonbondedForce_create() else {
      fatalError("Could not initialize.")
    }
    super.init(pointer)
    self.retain()
  }
  
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_NonbondedForce_destroy(pointer)
  }
}

class OpenMM_Platform: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Platform_destroy(pointer)
  }
  
  static var defaultPluginsDirectory: String? {
    let _directory = OpenMM_Platform_getDefaultPluginsDirectory()
    guard let _directory else {
      return nil
    }
    return String(cString: _directory)
  }
  
  static func loadPlugins(directory: String) -> OpenMM_StringArray? {
    let _plugins = OpenMM_Platform_loadPluginsFromDirectory(directory)
    guard let _plugins else {
      return nil
    }
    let plugins = OpenMM_StringArray(_plugins)
    plugins.retain()
    return plugins
  }
}

class OpenMM_State: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_State_destroy(pointer)
  }
}

class OpenMM_StringArray: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_StringArray_destroy(pointer)
  }
  
  var size: Int {
    let _size = OpenMM_StringArray_getSize(pointer)
    return Int(_size)
  }
  
  subscript(index: Int) -> String {
    get {
      let _element = OpenMM_StringArray_get(pointer, Int32(index))
      guard let _element else {
        fatalError("Index out of bounds.")
      }
      return String(cString: _element)
    }
    // `set` not supported yet.
  }
}

class OpenMM_System: OpenMM_Object {
  override init() {
    guard let pointer = OpenMM_System_create() else {
      fatalError("Could not initialize.")
    }
    super.init(pointer)
    self.retain()
  }
  
  /// Transfer ownership of the `OpenMM_Force` to OpenMM before calling this.
  // TODO: Function that adds the force.
  
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_System_destroy(pointer)
  }
}

class OpenMM_Vec3Array: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Vec3Array_destroy(pointer)
  }
  
  var size: Int {
    let _size = OpenMM_Vec3Array_getSize(pointer)
    return Int(_size)
  }
  
  subscript(index: Int) -> SIMD3<Double> {
    get {
      let _element = OpenMM_Vec3Array_get(pointer, Int32(index))
      guard let _element else {
        fatalError("Index out of bounds.")
      }
      
      // Cannot assume this is aligned to 4 x 8 bytes, so read each element
      // separately. If this part becomes a bottleneck in the CPU code, we know
      // how to fix it.
      let _vector: OpenMM_Vec3 = _element.pointee
      return SIMD3(_vector.x, _vector.y, _vector.z)
    }
    set {
      let _vector = OpenMM_Vec3(x: newValue.x, y: newValue.y, z: newValue.z)
      OpenMM_Vec3Array_set(pointer, Int32(index), _vector)
    }
  }
}
