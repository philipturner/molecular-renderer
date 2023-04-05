//
//  ContentView.swift
//  MolecularRenderer
//
//  Created by Philip Turner on 2/22/23.
//

import SwiftUI

// Credit: Partially sourced from https://developer.apple.com/documentation/metal/onscreen_presentation/creating_a_custom_metal_view

struct ContentView: View {
  @State var _bypassingSwiftUIMaybe = 0
  var coordinator: Coordinator = Coordinator()
  
  var body: some View {
    VStack {
      MetalView(coordinator: coordinator)
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
  func updateNSView(_ nsView: NSView, context: Context) {
//    let size = nsView.drawableSize
//    if size.width != 1024 || size.height != 1024 {
//      fatalError("Size cannot change.")
//    }
  }
}

class Coordinator: NSObject, ObservableObject, CustomMetalViewDelegate {
  var view: CustomMetalView!
  var renderer: Renderer!
  
  override init() {
    super.init()
    
    self.view = CustomMetalView()
    self.view.initCommon(delegate: self)
//    view.drawableSize = .init(width: 1024, height: 1024)
//    // If drawable changes, results are undefined.
//    view.autoResizeDrawable = false
    
    let castedLayer = view.layer as! CAMetalLayer
    castedLayer.framebufferOnly = false
    castedLayer.allowsNextDrawableTimeout = false
    
    let device = MTLCreateSystemDefaultDevice()!
    view.metalLayer.device = device
    view.metalLayer.pixelFormat = .rgb10a2Unorm
    
//    view.preferredFramesPerSecond = 120
//    view.device = MTLCreateSystemDefaultDevice()!
//    view.colorPixelFormat = .rgb10a2Unorm
    
    self.renderer = Renderer(device: device, view: view)
  }
  
  // This function would adapt to user-specific sizes, but for now we disallow
  // resizing.
//  func nsView(_ view: NSView, drawableSizeWillChange size: CGSize) {
//    if size.width != 1024 || size.height != 1024 {
//      fatalError("Size cannot change.")
//    }
//  }
  func drawableResize(_ size: CGSize) {
    if size.width != 1024 || size.height != 1024 {
      fatalError("Size cannot change.")
    }
  }
  
//  func draw(in view: NSView) {
//    precondition(view == self.view)
//    renderer.update()
//  }
  func renderToMetalLayer(_ metalLayer: CAMetalLayer) {
    renderer.renderToMetalLayer(metalLayer)
  }
}

protocol CustomMetalViewDelegate: NSObject {
  func drawableResize(_ size: CGSize)
  func renderToMetalLayer(_ metalLayer: CAMetalLayer)
}

final class CustomMetalView: NSView, CALayerDelegate {
  var metalLayer: CAMetalLayer!
  var paused: Bool = false
  var delegate: (any CustomMetalViewDelegate)!
  
  var displayLink: CVDisplayLink!
  var displaySource: DispatchSource!
  
  func initCommon(delegate: any CustomMetalViewDelegate) {
    self.delegate = delegate
    
    self.wantsLayer = true
    self.layerContentsRedrawPolicy = .duringViewResize
    self.metalLayer = (self.layer as! CAMetalLayer)
    print(metalLayer)
    
    print("part a")
    self.bounds.size = CGSize(
      width: 1024 / NSScreen.main!.backingScaleFactor,
      height: 1024 / NSScreen.main!.backingScaleFactor)
    print("part b")
    self.frame.size = CGSize(
      width: 1024 / NSScreen.main!.backingScaleFactor,
      height: 1024 / NSScreen.main!.backingScaleFactor)
    print("part c")
    
    self.layer!.delegate = self
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
//    self.initCommon()
  }
  
  required init(coder: NSCoder) {
    super.init(coder: coder)!
//    self.initCommon()
  }
  
  func resizeDrawable(_ scaleFactor: CGFloat) {
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    if size.width != 1024 || size.height != 1024 {
      print("Size cannot change. Continuing anyway")
      return
    }
    print(metalLayer)
    if size.width == metalLayer?.drawableSize.width,
       size.height == metalLayer?.drawableSize.height {
      return
    }
    metalLayer!.drawableSize = size
    delegate.drawableResize(size)
  }
  
  func render() {
    delegate.renderToMetalLayer(metalLayer)
  }
  
  override func makeBackingLayer() -> CALayer {
    return CAMetalLayer()
  }
  
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    
    self.setupCVDisplayLink(screen: self.window!.screen!)
    self.resizeDrawable(self.window!.screen!.backingScaleFactor)
  }
  
  func setupCVDisplayLink(screen: NSScreen) {
    displaySource = DispatchSource.makeUserDataAddSource(queue: .main) as? DispatchSource
    precondition(displaySource != nil, "This should never happen.")
    displaySource.setEventHandler(handler: { self.render() })
    displaySource.resume()
    
    // Set up the display link.
    checkCVDisplayError(
      CVDisplayLinkCreateWithActiveCGDisplays(&self.displayLink))
    
    checkCVDisplayError(CVDisplayLinkSetOutputCallback(
      displayLink
    , { link, timeStamp1, timeStamp2, flags, pointerFlags, context in
//      print()
//      print("Link: \(link)")
//      print("TimeStamp1: \(timeStamp1.pointee)")
//      print("TimeStamp2: \(timeStamp2.pointee)")
//      print("Flags: \(flags)")
//      print("PointerFlags: \(pointerFlags.pointee)")
//      print("Context: \(String(describing: context))")
      
      let source = Unmanaged<DispatchSource>
        .fromOpaque(context!).takeUnretainedValue() as DispatchSourceUserDataAdd
      source.add(data: 1)
      
      return kCVReturnSuccess
    }, Unmanaged.passUnretained(displaySource).toOpaque()))
    
    let windowScreen = self.window!.screen!
    checkCVDisplayError(
      CVDisplayLinkSetCurrentCGDisplay(displayLink, windowScreen.screenNumber))
    checkCVDisplayError(CVDisplayLinkStart(displayLink))
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(self, selector: #selector(windowWillClose), name: NSWindow.willCloseNotification, object: self.window!)
  }
  
  @objc func windowWillClose(notification: NSNotification) {
    if (notification.object! as AnyObject) === self.window! {
      checkCVDisplayError(CVDisplayLinkStop(displayLink))
    }
  }
  
  func stopRenderLoop() {
    if (displayLink != nil) {
      checkCVDisplayError(CVDisplayLinkStop(displayLink))
//      CVDisplayLinkRelease(displayLink)
      displaySource.cancel()
    }
  }
  
  // TODO: Ensure the view can't change its size now.
  
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    self.resizeDrawable(self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor)
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    self.resizeDrawable(self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor)
  }
  
  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    self.resizeDrawable(self.window?.screen?.backingScaleFactor ?? NSScreen.main!.backingScaleFactor)
  }
}
