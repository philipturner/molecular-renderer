//
//  MetalView.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import SwiftUI

// Partially sourced from:
// https://developer.apple.com/documentation/metal/onscreen_presentation/creating_a_custom_metal_view

struct MetalView: NSViewRepresentable {
  @ObservedObject var coordinator: Coordinator
  
  func makeCoordinator() -> Coordinator { coordinator }
  
  func makeNSView(context: Context) -> NSView { context.coordinator.view }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

final class RendererView: NSView, CALayerDelegate {
  var metalLayer: CAMetalLayer!
  var coordinator: Coordinator!
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self, selector: #selector(appMovedToBackground),
      name: NSApplication.willResignActiveNotification, object: nil)
    notificationCenter.addObserver(
      self, selector: #selector(appMovedToForeground),
      name: NSApplication.didBecomeActiveNotification, object: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  @objc func appMovedToBackground() {
    coordinator.eventTracker.windowInForeground.store(false, ordering: .relaxed)
  }
  
  @objc func appMovedToForeground() {
    coordinator.eventTracker.windowInForeground.store(true, ordering: .relaxed)
  }
  
  // Bypass the inability to change how it initializes.
  func initializeResources(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.wantsLayer = true
    self.layerContentsRedrawPolicy = .duringViewResize
    self.metalLayer = (self.layer as! CAMetalLayer)
    metalLayer.drawableSize = CGSize(
      width: ContentView.size, height: ContentView.size)
    
    self.bounds.size = CGSize(
      width: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor,
      height: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor)
    self.frame.size = CGSize(
      width: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor,
      height: CGFloat(ContentView.size) / NSScreen.main!.backingScaleFactor)
    self.layer!.delegate = self
  }
  
  override func makeBackingLayer() -> CALayer {
    return CAMetalLayer()
  }
  
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    
    if self.window == nil {
      // The user closed the window. Eventually, we might need to save stuff to
      // disk here. Exit to prevent Xcode from having numerous background apps
      // that won't close on their own.
      print("Exiting the app.")
      CGDisplayShowCursor(CGMainDisplayID())
      CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
      exit(0)
    } else {
      let screen = self.window!.screen!
      coordinator.vsyncHandler = VsyncHandler(
        coordinator: coordinator, screen: screen)
      resizeDrawable(screen.backingScaleFactor)
    }
  }
  
  func resizeDrawable(_ scaleFactor: CGFloat) {
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    
    if size.width != CGFloat(ContentView.size) ||
        size.height != CGFloat(ContentView.size) {
      if size.width != 0 ||
          size.height != 0 {
        fatalError("Size cannot change.")
      }
    }
  }
  
  var backingScaleFactor: CGFloat {
    self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor
  }
  
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    resizeDrawable(self.backingScaleFactor)
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    resizeDrawable(self.backingScaleFactor)
  }
  
  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    resizeDrawable(self.backingScaleFactor)
  }
}
