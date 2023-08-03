//
//  initOpenMM.swift
//  MolecularRendererApp
//
//  Created by Philip Turner on 6/25/23.
//

import Foundation
import OpenMM

// Use OpenMM for prototyping MD algorithms and developing the serialization
// format for MolecularRenderer.

public func initOpenMM() {
  // Disable the nearest neighbor list because we run very small simulations.
  setenv("OPENMM_METAL_USE_NEIGHBOR_LIST", "1", 1)
  
  // Slightly optimize energy reductions while minimizing the increase in power
  // consumption, which harms performance for larger systems.
  setenv("OPENMM_METAL_REDUCE_ENERGY_THREADGROUPS", "2", 1)
  
  let strLogLevel = getenv("MOLECULAR_RENDERER_LOG_LEVEL")
  var logLevel = 0
  if let strLogLevel {
    guard let intLogLevel = Int(String(cString: strLogLevel) as String) else {
      fatalError("Invalid log level: \(strLogLevel)")
    }
    logLevel = intLogLevel
  }
  
  let directory = OpenMM_Platform.defaultPluginsDirectory!
  if logLevel >= 1 {
    print("OpenMM plugins directory: \(directory)")
  }
  
  let plugins = OpenMM_Platform.loadPlugins(directory: directory)!
  let numPlugins = plugins.size
  if logLevel >= 1 {
    print("Number of plugins: \(numPlugins)")
  }
  
  for i in 0..<numPlugins {
    if logLevel >= 1 {
      print("Plugin \(i + 1): \(plugins[i])")
    }
  }
}

