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
