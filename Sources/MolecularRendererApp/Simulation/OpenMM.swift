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
  
  // Slightly optimize energy reductions while minimizing the increase in power
  // consumption, which harms performance for larger systems.
  setenv("OPENMM_METAL_REDUCE_ENERGY_THREADGROUPS", "2", 1)
  
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

@inline(__always)
fileprivate func _openmm_create(
  _ closure: @convention(c) () -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure() else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
fileprivate func _openmm_create<T>(
  _ argument1: T,
  _ closure: (T) -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure(argument1) else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
fileprivate func _openmm_create<T, U>(
  _ argument1: T,
  _ argument2: U,
  _ closure: (T, U) -> OpaquePointer?
) -> OpaquePointer {
  guard let result = closure(argument1, argument2) else {
    fatalError("Could not initialize.")
  }
  return result
}

@inline(__always)
fileprivate func _openmm_get<S>(
  _ caller: OpaquePointer,
  _ closure: (OpaquePointer?) -> S?,
  function: StaticString = #function
) -> S {
  guard let result = closure(caller) else {
    fatalError("Could not retrieve property '\(function)'.")
  }
  return result
}

@inline(__always)
fileprivate func _openmm_index_get<S>(
  _ caller: OpaquePointer,
  _ index: Int,
  _ closure: (OpaquePointer?, Int32) -> S?,
  function: StaticString = #function
) -> S {
  let _index = Int32(truncatingIfNeeded: index)
  guard let result = closure(caller, _index) else {
    fatalError("Index out of bounds.")
  }
  return result
}

// _openmm_index_set

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

class OpenMM_Context: OpenMM_Object {
  convenience init(system: OpenMM_System, integrator: OpenMM_Integrator) {
    self.init(_openmm_create(
      system.pointer, integrator.pointer, OpenMM_Context_create))
    self.retain()
  }
  
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Context_destroy(pointer)
  }
  
  var platform: OpenMM_Platform {
    .init(_openmm_get(pointer, OpenMM_Context_getPlatform))
  }
}

class OpenMM_Force: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Force_destroy(pointer)
  }
}

class OpenMM_Integrator: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Integrator_destroy(pointer)
  }
}

class OpenMM_NonbondedForce: OpenMM_Force {
  override init() {
    super.init(_openmm_create(OpenMM_NonbondedForce_create))
    self.retain()
  }
  
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_NonbondedForce_destroy(pointer)
  }
  
  @discardableResult
  func addParticle(charge: Double, sigma: Double, epsilon: Double) -> Int {
    let index = OpenMM_NonbondedForce_addParticle(
      pointer, charge, sigma, epsilon)
    return Int(index)
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
  
  var name: String {
    .init(cString: _openmm_get(pointer, OpenMM_Platform_getName))
  }
}

class OpenMM_State: OpenMM_Object {
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_State_destroy(pointer)
  }
  
  var positions: OpenMM_Vec3Array {
    .init(_openmm_get(pointer, OpenMM_State_getPositions))
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
      .init(cString: _openmm_index_get(pointer, index, OpenMM_StringArray_get))
    }
    // `set` not supported yet.
  }
}

class OpenMM_System: OpenMM_Object {
  override init() {
    super.init(_openmm_create(OpenMM_System_create))
    self.retain()
  }
  
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_System_destroy(pointer)
  }
  
  /// Transfer ownership of the `OpenMM_Force` to OpenMM before calling this.
  @discardableResult
  func addForce(_ force: OpenMM_Force) -> Int {
    let index = OpenMM_System_addForce(pointer, force.pointer)
    return Int(index)
  }
  
  @discardableResult
  func addParticle(mass: Double) -> Int {
    let index = OpenMM_System_addParticle(pointer, mass)
    return Int(index)
  }
}

class OpenMM_Vec3Array: OpenMM_Object {
  convenience init(size: Int) {
    self.init(_openmm_create(Int32(size), OpenMM_Vec3Array_create))
    self.retain()
  }
  
  override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Vec3Array_destroy(pointer)
  }
  
  var size: Int {
    let _size = OpenMM_Vec3Array_getSize(pointer)
    return Int(_size)
  }
  
  subscript(index: Int) -> SIMD3<Double> {
    get {
      let _element = _openmm_index_get(pointer, index, OpenMM_Vec3Array_get)
      
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

class OpenMM_VerletIntegrator: OpenMM_Integrator {
  convenience init(stepSize: Double) {
    self.init(_openmm_create(stepSize, OpenMM_VerletIntegrator_create))
    self.retain()
  }
}
