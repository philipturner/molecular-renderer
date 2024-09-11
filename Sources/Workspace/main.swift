// swift package init --type executable
// Copy the following code into 'main.swift'.
// Change the platforms to '[.macOS(.v14)]' in the package manifest.
// swift run -Xswiftc -Ounchecked

// https://www.polpiella.dev/launching-a-swiftui-view-from-the-terminal

// Next steps:
// - Copying the code.
//    - Save the code to a GitHub gist for reference.
//    - Make a cleaned molecular-renderer branch.
//    - Copy the above code into the branch.
//    - Test the code.
//    - Commit the files to Git.
// - Access the GPU.
//   - Modify it to get Metal rendering.
//   - Integrate a CVDisplayLink to get information about the time each frame.
//   - Run a test of timestamp synchronization.
// - Repeat the same process with COM / D3D12 on Windows.

import AppKit

// MARK: - AAPLAppDelegate

class AAPLAppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(
    _ app: NSApplication
  ) -> Bool {
    return true
  }
}

// MARK: - AAPLView

protocol AAPLViewDelegate {
  func resizeDrawable(_ size: CGSize)
  func renderToMetalLayer(metalLayer: CAMetalLayer)
}

class AAPLView: NSView, CALayerDelegate {
  var metalLayer: CAMetalLayer!
  var paused: Bool = false
  var delegate: AAPLViewDelegate!
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    initCommon()
  }
  
  required init(coder: NSCoder) {
    fatalError("Coder init not supported.")
  }
  
  func initCommon() {
    metalLayer = self.layer! as? CAMetalLayer
    self.layer!.delegate = self
  }
  
  func resizeDrawable(_ scaleFactor: CGFloat) {
    // Fetch the bounds and multiply by the scale factor.
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    
    // Check that the resolved size is what we want.
    if size.width != CGFloat(1920) ||
        size.height != CGFloat(1920) {
      if size.width != 0 ||
          size.height != 0 {
        fatalError("Size cannot change.")
      }
    }
    
    metalLayer.drawableSize = size
    delegate.resizeDrawable(size)
  }
  
  func render() {
    delegate.renderToMetalLayer(metalLayer: metalLayer)
  }
}

// MARK: - AAPLViewController

class AAPLViewController: NSViewController, AAPLViewDelegate {
  var renderer: AAPLRenderer!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let device = MTLCreateSystemDefaultDevice()!
    let view = self.view as! AAPLView
    view.metalLayer.device = device
    view.delegate = self
    view.metalLayer.pixelFormat = .rgb10a2Unorm
    
    renderer = AAPLRenderer(
      device: device,
      drawablePixelFormat: view.metalLayer.pixelFormat)
  }
  
  func resizeDrawable(_ size: CGSize) {
    renderer.resizeDrawable(size)
  }
  
  func renderToMetalLayer(metalLayer layer: CAMetalLayer) {
    renderer.renderToMetalLayer(metalLayer: layer)
  }
}

// MARK: - AAPLNSView

class AAPLNSView: AAPLView {
  var displayLink: CVDisplayLink!
  
  var backingScaleFactor: CGFloat {
    guard let window = self.window,
          let screen = window.screen else {
      fatalError("Could not retrieve screen.")
    }
    return screen.backingScaleFactor
  }
  
  override func initCommon() {
    self.wantsLayer = true
    self.layerContentsRedrawPolicy = .duringViewResize
    super.initCommon()
  }
  
  override func makeBackingLayer() -> CALayer {
    return CAMetalLayer()
  }
  
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    
    guard let window = self.window,
          let screen = window.screen else {
      fatalError("Could not retrieve screen.")
    }
    setupCVDisplayLinkForScreen(screen: screen)
    resizeDrawable(backingScaleFactor)
  }
  
  func setupCVDisplayLinkForScreen(screen: NSScreen) {
    // Initialize a display link that can be used with all of the displays.
    do {
      let cvReturn = CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
      guard cvReturn == kCVReturnSuccess else {
        fatalError("CVReturn was not success.")
      }
    }
    
    // Set the callback function, supplying this view as its argument.
    do {
      let unmanaged = Unmanaged<AAPLNSView>.passUnretained(self)
      let selfPointer = unmanaged.toOpaque()
      let cvReturn = CVDisplayLinkSetOutputCallback(
        displayLink, DispatchRenderLoop, selfPointer)
      guard cvReturn == kCVReturnSuccess else {
        fatalError("CVReturn was not success.")
      }
    }
    
    // Associate the display link with the display where the view is.
    do {
      let screen = self.window!.screen!
      let key = NSDeviceDescriptionKey("NSScreenNumber")
      guard let screenNumberAny = screen.deviceDescription[key],
            let screenNumber = screenNumberAny as? NSNumber else {
        fatalError("Could not retrieve screen number.")
      }
      let cvReturn = CVDisplayLinkSetCurrentCGDisplay(
        displayLink, screenNumber.uint32Value)
      guard cvReturn == kCVReturnSuccess else {
        fatalError("CVReturn was not success.")
      }
    }
    
    // Start the display link.
    do {
      let cvReturn = CVDisplayLinkStart(displayLink)
      guard cvReturn == kCVReturnSuccess else {
        fatalError("CVReturn was not success.")
      }
    }
    
    // Register to be notified when the window closes.
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(windowWillClose(notification:)),
      name: NSWindow.willCloseNotification,
      object: self.window!)
  }
  
  @objc
  func windowWillClose(notification: NSNotification) {
    exit(0)
  }
  
  override func viewDidChangeBackingProperties() {
    super.viewDidChangeBackingProperties()
    resizeDrawable(backingScaleFactor)
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    super.setFrameSize(newSize)
    resizeDrawable(backingScaleFactor)
  }
  
  override func setBoundsSize(_ newSize: NSSize) {
    super.setBoundsSize(newSize)
    resizeDrawable(backingScaleFactor)
  }
}

// Must be declared in the global scope to get @convention(c) status.
func DispatchRenderLoop(
  displayLink: CVDisplayLink,
  now: UnsafePointer<CVTimeStamp>,
  outputTime: UnsafePointer<CVTimeStamp>,
  flagsIn: UInt64,
  flagsOut: UnsafeMutablePointer<UInt64>,
  displayLinkContext: UnsafeMutableRawPointer?
) -> Int32 {
  guard let displayLinkContext else {
    fatalError("Could not retrieve display link context.")
  }
  let unmanaged = Unmanaged<AAPLNSView>.fromOpaque(displayLinkContext)
  let customView = unmanaged.takeUnretainedValue()
  customView.render()
  
  return kCVReturnSuccess
}

// MARK: - AAPLRenderer

class AAPLRenderer: NSObject {
  var device: MTLDevice!
  var commandQueue: MTLCommandQueue!
  var computePipelineState: MTLComputePipelineState!
  
  var viewportSize: SIMD2<UInt32> = .zero
  var frameNumber: Int = .zero
  
  init(
    device: MTLDevice,
    drawablePixelFormat: MTLPixelFormat
  ) {
    // Initialize the NSObject.
    super.init()
    
    // Set the device property.
    self.device = device
    
    // Set the command queue property.
    guard let commandQueue = device.makeCommandQueue() else {
      fatalError("Failed to make command queue.")
    }
    self.commandQueue = commandQueue
    
    // Set the PSO property.
    self.computePipelineState = AAPLShaders
      .createComputePipelineState(device: device)
  }
  
  func renderToMetalLayer(metalLayer: CAMetalLayer) {
    frameNumber += 1
    
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let currentDrawable = metalLayer.nextDrawable()
    guard let currentDrawable else {
      fatalError("Could not retrieve next drawable.")
    }
    
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(computePipelineState)
    encoder.setTexture(currentDrawable.texture, index: 0)
    encoder.dispatchThreads(
      MTLSize(width: 1920, height: 1920, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    
    encoder.endEncoding()
    commandBuffer.present(currentDrawable)
    commandBuffer.commit()
  }
  
  func resizeDrawable(_ drawableSize: CGSize) {
    viewportSize.x = UInt32(drawableSize.width)
    viewportSize.y = UInt32(drawableSize.height)
  }
}

// MARK: - AAPLShaders

class AAPLShaders {
  static func createSource() -> String {
    """
    
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void renderImage(
      texture2d<half, access::write> drawableTexture [[texture(0)]],
      ushort2 tid [[thread_position_in_grid]]
    ) {
      half4 color = half4(1.00, 0.00, 0.00, 1.00);
      drawableTexture.write(color, tid);
    }
    
    """
  }
  
  static func createComputePipelineState(
    device: MTLDevice
  ) -> MTLComputePipelineState {
    // JIT-compile the shader code into a library.
    let shaderSource = AAPLShaders.createSource()
    let library = try! device.makeLibrary(source: shaderSource, options: nil)
    
    // Load the Metal function.
    let function = library.makeFunction(name: "renderImage")
    guard let function else {
      fatalError("Could not make function.")
    }
    
    // Initialize the pipeline state object.
    let pipeline = try! device.makeComputePipelineState(function: function)
    return pipeline
  }
}

// MARK: - Launching the Application

// Run the application.
let appDelegate = AAPLAppDelegate()
withExtendedLifetime(appDelegate) {
  let app = NSApplication.shared
  app.delegate = appDelegate
  app.setActivationPolicy(.regular)
  app.activate(ignoringOtherApps: true)
  app.run()
}
