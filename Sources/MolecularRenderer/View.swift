import AppKit

class View: NSView, CALayerDelegate {
  nonisolated(unsafe) var metalLayer: CAMetalLayer
  var windowSize: Int
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    metalLayer = CAMetalLayer()
    windowSize = display.windowSize
    super.init(frame: .zero)
    
    func createCGSize(_ width: Int) -> CGSize {
      let widthDouble = Double(width)
      let cgSize = CGSize(width: widthDouble, height: widthDouble)
      return cgSize
    }
    
    metalLayer.delegate = self
    metalLayer.device = MTLCreateSystemDefaultDevice()!
    metalLayer.drawableSize = createCGSize(display.renderTargetSize)
    metalLayer.framebufferOnly = false
    metalLayer.pixelFormat = .rgb10a2Unorm
    
    self.bounds.size = createCGSize(display.windowSize)
    self.frame.size = createCGSize(display.windowSize)
    self.layerContentsRedrawPolicy = .never
    self.wantsLayer = true
  }
  
  override func makeBackingLayer() -> CALayer {
    metalLayer
  }
}

extension View {
  func checkDrawableSize(_ newSize: NSSize) {
    guard newSize.width == Double(windowSize),
          newSize.height == Double(windowSize) else {
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
