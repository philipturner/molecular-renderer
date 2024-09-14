import AppKit

class View: NSView, CALayerDelegate {
  var display: Display
  var metalLayer: CAMetalLayer
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    self.display = display
    metalLayer = CAMetalLayer()
    super.init(frame: .zero)
    
    self.layerContentsRedrawPolicy = .duringViewResize
    self.wantsLayer = true
    metalLayer.drawableSize = CGSize(
      width: Double(display.renderTargetSize),
      height: Double(display.renderTargetSize))
    
    metalLayer.delegate = self
    
    var windowSize = Double(display.renderTargetSize)
    windowSize /= display.screen.backingScaleFactor
    self.bounds.size = CGSize(
      width: Double(windowSize),
      height: Double(windowSize))
    self.frame.size = CGSize(
      width: Double(windowSize),
      height: Double(windowSize))
    
    metalLayer.device = MTLCreateSystemDefaultDevice()!
    metalLayer.framebufferOnly = false
    metalLayer.pixelFormat = .rgb10a2Unorm
  }
  
  override func makeBackingLayer() -> CALayer {
    metalLayer
  }
}

extension View {
  func checkDrawableSize(_ newSize: NSSize) {
    guard newSize.width == Double(display.windowSize),
          newSize.height == Double(display.windowSize) else {
      fatalError("Attempted to resize the window.")
    }
  }
  
  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    checkDrawableSize(newSize)
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    checkDrawableSize(newSize)
  }
}
