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
  let directory = OpenMM_Platform_getDefaultPluginsDirectory()
  guard let directory else {
    fatalError("No directory.")
  }
  print("OpenMM plugins directory: \(directory)")
  
  let plugins = OpenMM_Platform_loadPluginsFromDirectory(directory)
  guard let plugins else {
    fatalError("No plugins.")
  }
  defer { OpenMM_StringArray_destroy(plugins) }
  print("Found plugins!")
  
  let numPlugins = OpenMM_StringArray_getSize(plugins)
  print("Number of plugins: \(numPlugins)")
  
  for i in 0..<numPlugins {
    var message = "Plugin \(i + 1): "
    let repr = OpenMM_StringArray_get(plugins, i)!
    message += String(cString: repr)
    print(message)
  }
}
