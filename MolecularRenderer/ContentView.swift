//
//  ContentView.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import SwiftUI
import MetalKit

struct ContentView: View {
  var body: some View {
    VStack {
      MetalView(coordinator: Coordinator())
        .disabled(false)
        .frame(
          width: 1024 / NSScreen.main!.backingScaleFactor,
          height: 1024 / NSScreen.main!.backingScaleFactor)
        .position(
          x: 512 / NSScreen.main!.backingScaleFactor,
          y: 512 / NSScreen.main!.backingScaleFactor)
    }
    .padding()
  }
}

struct MetalView: NSViewRepresentable {
  @ObservedObject var coordinator: Coordinator
  
  func makeCoordinator() -> Coordinator { coordinator }
  
  func makeNSView(context: Context) -> MTKView { context.coordinator.view }
  func updateNSView(_ nsView: MTKView, context: Context) {
    let size = nsView.drawableSize
    if size.width != 1024 || size.height != 1024 {
      fatalError("Size cannot change.")
    }
  }
}

class Coordinator: NSObject, ObservableObject, MTKViewDelegate {
  var view: MTKView
  var renderer: Renderer
  
  override init() {
    self.view = MTKView()
    view.drawableSize = .init(width: 1024, height: 1024)
    // If drawable changes, results are undefined.
    view.autoResizeDrawable = false
    
    let castedLayer = view.layer as! CAMetalLayer
    castedLayer.framebufferOnly = false
    castedLayer.allowsNextDrawableTimeout = false
    view.preferredFramesPerSecond = 120
    view.device = MTLCreateSystemDefaultDevice()!
    view.colorPixelFormat = .rgb10a2Unorm
    
    self.renderer = Renderer(view: view)
    
    super.init()
    view.delegate = self
  }
  
  // This function would adapt to user-specific sizes, but for now we disallow
  // resizing.
  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
    if size.width != 1024 || size.height != 1024 {
      fatalError("Size cannot change.")
    }
  }
  
  func draw(in view: MTKView) {
    precondition(view == self.view)
    renderer.update()
  }
}
