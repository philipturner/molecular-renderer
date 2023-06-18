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

// TODO: Extract this into the Swift module, rename the current "OpenMM" as
// "COpenMM", and call the wrappers the new "OpenMM".

class OpenMM_Object {
  var pointer: OpaquePointer
  private var retain: Bool
  
  init(_ pointer: OpaquePointer?, retain: Bool = false) {
    guard let pointer else {
      fatalError("OpenMM object pointer was null.")
    }
    self.pointer = pointer
    self.retain = retain
  }
  
  class func destroy(_ pointer: OpaquePointer) {
    fatalError("'destroy' not implemented.")
  }
  
  deinit {
    if retain {
      Self.destroy(pointer)
    }
  }
}

// MARK: - OpenMM Constants

// Probably need something like @_exported import OpenMM_PsPerFs

// MARK: - OpenMM Classes

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
    return OpenMM_StringArray(_plugins, retain: true)
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
    let _element = OpenMM_StringArray_get(pointer, Int32(index))
    guard let _element else {
      fatalError("Index out of bounds.")
    }
    return String(cString: _element)
  }
}
