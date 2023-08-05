//
//  OpenMM_Context.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import COpenMM

public class OpenMM_Context: OpenMM_Object {
  public convenience init(
    system: OpenMM_System, integrator: OpenMM_Integrator
  ) {
    self.init(_openmm_create(
      system.pointer, integrator.pointer, OpenMM_Context_create))
    self.retain()
  }
  
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Context_destroy(pointer)
  }
  
  public var platform: OpenMM_Platform {
    .init(_openmm_get(pointer, OpenMM_Context_getPlatform))
  }
  
  public var positions: OpenMM_Vec3Array {
     get {
      _openmm_no_getter()
    }
    set {
      OpenMM_Context_setPositions(pointer, newValue.pointer)
    }
  }
  
  public func setVelocitiesToTemperature(
    _ temperature: Double,
    _ randomSeed: Int = .random(in: 0...Int.max)
  ) {
    OpenMM_Context_setVelocitiesToTemperature(
      pointer, temperature, Int32(randomSeed % (Int(Int32.max) + 1)))
  }
  
  public func state(
    types: OpenMM_State.DataType,
    enforcePeriodicBox: Bool = false,
    groups: Int? = nil
  ) -> OpenMM_State {
    var _state: OpaquePointer
    if let groups {
      _state = _openmm_get(
        pointer, Int32(truncatingIfNeeded: types.rawValue),
        enforcePeriodicBox ? 1 : 0, Int32(groups), OpenMM_Context_getState_2)
    } else {
      _state = _openmm_get(
        pointer, Int32(truncatingIfNeeded: types.rawValue),
        enforcePeriodicBox ? 1 : 0, OpenMM_Context_getState)
    }
    
    let state = OpenMM_State(_state)
    state.retain()
    return state
  }
  
  public var velocities: OpenMM_Vec3Array {
     get {
      _openmm_no_getter()
    }
    set {
      OpenMM_Context_setVelocities(pointer, newValue.pointer)
    }
  }
}

public class OpenMM_Platform: OpenMM_Object {
  public override class func destroy(_ pointer: OpaquePointer) {
    OpenMM_Platform_destroy(pointer)
  }
  
  public static var defaultPluginsDirectory: String? {
    let _directory = OpenMM_Platform_getDefaultPluginsDirectory()
    guard let _directory else {
      return nil
    }
    return String(cString: _directory)
  }
  
  @discardableResult
  public static func loadPlugins(directory: String) -> OpenMM_StringArray? {
    let _plugins = OpenMM_Platform_loadPluginsFromDirectory(directory)
    guard let _plugins else {
      return nil
    }
    let plugins = OpenMM_StringArray(_plugins)
    plugins.retain()
    return plugins
  }
  
  public static func loadPluginLibrary(file: String) {
    OpenMM_Platform_loadPluginLibrary(file)
  }
  
  public var name: String {
    .init(cString: _openmm_get(pointer, OpenMM_Platform_getName))
  }
}
