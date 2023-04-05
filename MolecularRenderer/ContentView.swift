//
//  ContentView.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import SwiftUI

// Credit: Partially sourced from https://developer.apple.com/documentation/metal/onscreen_presentation/creating_a_custom_metal_view

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
    .padding(.zero)
  }
}

struct MetalView: NSViewRepresentable {
  @ObservedObject var coordinator: Coordinator
  
  func makeCoordinator() -> Coordinator { coordinator }
  
  func makeNSView(context: Context) -> NSView { context.coordinator.view }
  func updateNSView(_ nsView: NSView, context: Context) {}
}

class Coordinator: NSObject, ObservableObject {
  var view: CustomMetalView!
  var renderer: Renderer!
  var displayLink: CVDisplayLink!
  var displaySource: DispatchSourceUserDataAdd!
  
  override init() {
    super.init()
    
    self.view = CustomMetalView()
    self.view.initializeResources(coordinator: self)
    
    view.metalLayer.framebufferOnly = false
    view.metalLayer.allowsNextDrawableTimeout = false
    view.metalLayer.pixelFormat = .rgb10a2Unorm
    
    self.renderer = Renderer(view: view)
    view.metalLayer.device = renderer.device
  }
  
  // This function would adapt to user-specific sizes, but for now we disallow
  // resizing.
  func drawableResize(_ size: CGSize) {
    if size.width != 1024 || size.height != 1024 {
      fatalError("Size cannot change.")
    }
  }
  
  func setupCVDisplayLink(screen: NSScreen) {
    // Initialize something that can legally fetch data from the UI.
    displaySource = DispatchSource.makeUserDataAddSource(queue: .main)
    displaySource.setEventHandler(handler: {
      // Prevents the renderer from updating the frame index erratically if you
      // switch to a 60 Hz or 30 Hz screen.
      let refreshRate = self.view.window!.screen!.maximumFramesPerSecond
      self.renderer.currentRefreshRate.store(
        refreshRate, ordering: .relaxed)
    })
    displaySource.resume()
    
    // Set up the display link.
    checkCVDisplayError(
      CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink))
    checkCVDisplayError(CVDisplayLinkSetOutputHandler(displayLink) {
      self.displaySource.add(data: 1)
      return self.renderer.vsyncHandler($0, $1, $2, $3, $4)
    })
    checkCVDisplayError(
      CVDisplayLinkSetCurrentCGDisplay(
        displayLink, view.window!.screen!.screenNumber))
    checkCVDisplayError(CVDisplayLinkStart(displayLink))
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self, selector: #selector(windowWillClose),
      name: NSWindow.willCloseNotification, object: view.window!)
  }
  
  @objc func windowWillClose(notification: NSNotification) {
    if (notification.object! as AnyObject) === view.window! {
      checkCVDisplayError(CVDisplayLinkStop(self.displayLink))
    }
  }
  
  func stopRenderLoop() {
    if (displayLink != nil) {
      checkCVDisplayError(CVDisplayLinkStop(displayLink))
    }
  }
}

final class CustomMetalView: NSView, CALayerDelegate {
  var metalLayer: CAMetalLayer!
  var coordinator: Coordinator!
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  // Bypass the inability to change how it initializes.
  func initializeResources(coordinator: Coordinator) {
    self.coordinator = coordinator
    self.wantsLayer = true
    self.layerContentsRedrawPolicy = .duringViewResize
    self.metalLayer = (self.layer as! CAMetalLayer)
    metalLayer.drawableSize = CGSize(width: 1024, height: 1024)
    
    self.bounds.size = CGSize(
      width: 1024 / NSScreen.main!.backingScaleFactor,
      height: 1024 / NSScreen.main!.backingScaleFactor)
    self.frame.size = CGSize(
      width: 1024 / NSScreen.main!.backingScaleFactor,
      height: 1024 / NSScreen.main!.backingScaleFactor)
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
      exit(0)
    } else {
      coordinator.setupCVDisplayLink(screen: self.window!.screen!)
      resizeDrawable(self.window!.screen!.backingScaleFactor)
    }
  }
  
  func resizeDrawable(_ scaleFactor: CGFloat) {
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    if size.width != 1024 || size.height != 1024 {
      if size.width != 0 || size.height != 0 {
        fatalError("Size cannot change.")
      }
    }
  }
  
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    resizeDrawable(self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor)
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    resizeDrawable(self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor)
  }
  
  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    resizeDrawable(self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor)
  }
}
