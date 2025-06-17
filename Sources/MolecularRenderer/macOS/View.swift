#if os(macOS)
import AppKit

class View: NSView, CALayerDelegate {
  nonisolated(unsafe) var metalLayer: CAMetalLayer
  private var contentSize: SIMD2<Double>
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    metalLayer = CAMetalLayer()
    contentSize = display.contentSize
    super.init(frame: .zero)
    
    func createCGSize(_ size: SIMD2<Double>) -> CGSize {
      CGSize(width: size[0], height: size[1])
    }
    
    metalLayer.delegate = self
    metalLayer.device = MTLCreateSystemDefaultDevice()!
    metalLayer.drawableSize = createCGSize(
      SIMD2<Double>(display.frameBufferSize))
    metalLayer.framebufferOnly = false
    metalLayer.pixelFormat = .rgb10a2Unorm
    
    self.bounds.size = createCGSize(display.contentSize)
    self.frame.size = createCGSize(display.contentSize)
    self.layerContentsRedrawPolicy = .never
    self.wantsLayer = true
  }
  
  override func makeBackingLayer() -> CALayer {
    metalLayer
  }
}

extension View {
  func checkDrawableSize(_ newSize: NSSize) {
    guard newSize.width == contentSize[0],
          newSize.height == contentSize[1] else {
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

#endif
