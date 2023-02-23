//
//  Renderer.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import MetalKit

// TODO: Establish 90-degree FOV until window resizing is allowed. Afterward,
// FOV in each direction changes to match the number of pixels. This might be
// able to be hard-coded into the shader.

class Renderer {
  var view: MTKView
  var refreshRate: Int
  
  init(view: MTKView) {
    self.view = view
    self.refreshRate =  NSScreen.main!.maximumFramesPerSecond
  }
}

extension Renderer {
  func update() {
    
  }
}
