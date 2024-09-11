// swift package init --type executable
// Copy the following code into 'main.swift'.
// Change the platforms to '[.macOS(.v14)]' in the package manifest.
// swift run -Xswiftc -Ounchecked

// https://www.polpiella.dev/launching-a-swiftui-view-from-the-terminal

// Next steps:
// - Copying the code. [DONE]
//    - Save the code to a GitHub gist for reference.
//    - Make a cleaned molecular-renderer branch.
//    - Copy the above code into the branch.
//    - Test the code.
//    - Commit the files to Git.
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible.
//   - Get timestamps synchronizing properly (moving rainbow banner scene).
// - Repeat the same process with COM / D3D12 on Windows.
//   - Another single-file Swift script that does the same thing.

import AppKit

extension NSScreen {
  static var fastest: NSScreen {
    screens.max(by: {
      $0.maximumFramesPerSecond < $1.maximumFramesPerSecond
    })!
  }
}

// MARK: - AAPLAppDelegate

class AAPLAppDelegate: NSObject, NSApplicationDelegate {
  let window = NSWindow(
    contentRect: .zero,
    styleMask: [.closable, .resizable, .titled],
    backing: .buffered,
    defer: false,
    screen: NSScreen.fastest)
  
  var responder: AAPLResponder!
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    window.contentViewController = AAPLViewController()
    window.makeKey()
    window.center()
    window.orderFrontRegardless()
    
    responder = AAPLResponder()
    responder.registerResponses(window: window)
    window.makeFirstResponder(responder)
  }
  
  func applicationShouldTerminateAfterLastWindowClosed(
    _ app: NSApplication
  ) -> Bool {
    return true
  }
}

// MARK: - AAPLView

protocol AAPLViewDelegate {
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
    
    delegate = AAPLViewController()
  }
  
  func resizeDrawable(_ scaleFactor: CGFloat) {
    // Resolve the actual size.
    var size = self.bounds.size
    size.width *= scaleFactor
    size.height *= scaleFactor
    
    // Check that the resolved size is what we want.
    switch (size.width, size.height) {
    case (0, 0):
      // The window is still opening.
      break
    case (1920, 1920):
      // Rendering content to the screen.
      break
    default:
      fatalError("Not allowed to resize window.")
    }
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
    
    do {
      let view = AAPLNSView()
      self.view = view
    }
    
    let device = MTLCreateSystemDefaultDevice()!
    let view = self.view as! AAPLView
    view.metalLayer.device = device
    view.delegate = self
    
    view.metalLayer.framebufferOnly = false
    view.metalLayer.pixelFormat = .rgb10a2Unorm
    
    renderer = AAPLRenderer(
      device: device,
      drawablePixelFormat: view.metalLayer.pixelFormat)
  }
  
  func renderToMetalLayer(metalLayer layer: CAMetalLayer) {
    guard let renderer else {
      fatalError("Rendered to Metal layer when renderer was not initialized.")
    }
    renderer.renderToMetalLayer(metalLayer: layer)
  }
}

// MARK: - AAPLNSView

class AAPLNSView: AAPLView {
  var displayLink: CVDisplayLink!
  
  var backingScaleFactor: CGFloat {
    if let window = self.window,
       let screen = window.screen {
      return screen.backingScaleFactor
    } else {
      let screen = NSScreen.fastest
      return screen.backingScaleFactor
    }
  }
  
  override func initCommon() {
    print("checkpoint 3.0")
    self.wantsLayer = true
    self.layerContentsRedrawPolicy =  .duringViewResize
    print("checkpoint 3.1")
    super.initCommon()
    
    print("checkpoint 3.2")
    metalLayer.drawableSize = CGSize(width: 1920, height: 1920)
    print("checkpoint 3.3")
    self.bounds.size = CGSize(
      width: CGFloat(1920) / NSScreen.fastest.backingScaleFactor,
      height: CGFloat(1920) / NSScreen.fastest.backingScaleFactor)
    print("checkpoint 3.4")
    self.frame.size = CGSize(
      width: CGFloat(1920) / NSScreen.fastest.backingScaleFactor,
      height: CGFloat(1920) / NSScreen.fastest.backingScaleFactor)
    print("checkpoint 3.5")
  }
  
  override func makeBackingLayer() -> CALayer {
    print("checkpoint 4.0")
    return CAMetalLayer()
  }
  
  override func viewDidMoveToWindow() {
    print("checkpoint 5.0")
    super.viewDidMoveToWindow()
    print("checkpoint 5.1")
    setupCVDisplayLinkForScreen()
    print("checkpoint 5.2")
    resizeDrawable(backingScaleFactor)
    print("checkpoint 5.3")
  }
  
  func setupCVDisplayLinkForScreen() {
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
      let screen = NSScreen.fastest
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
  }
  
  override func viewDidChangeBackingProperties() {
    print("checkpoint 0.0")
    super.viewDidChangeBackingProperties()
    print("checkpoint 0.1")
    resizeDrawable(backingScaleFactor)
    print("checkpoint 0.2")
  }
  
  override func setFrameSize(_ newSize: NSSize) {
    print("checkpoint 1.0")
    super.setFrameSize(newSize)
    print("checkpoint 1.1")
    resizeDrawable(backingScaleFactor)
    print("checkpoint 1.2")
  }
  
  override func setBoundsSize(_ newSize: NSSize) {
    print("checkpoint 2.0")
    super.setBoundsSize(newSize)
    print("checkpoint 2.1")
    resizeDrawable(backingScaleFactor)
    print("checkpoint 2.2")
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
    
    do {
      var bytes = UInt32(frameNumber)
      encoder.setBytes(&bytes, length: 4, index: 0)
    }
    
    encoder.setTexture(currentDrawable.texture, index: 0)
    encoder.dispatchThreads(
      MTLSize(width: 1920, height: 1920, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    
    encoder.endEncoding()
    commandBuffer.present(currentDrawable)
    commandBuffer.commit()
  }
}

// MARK: - AAPLShaders

class AAPLShaders {
  static func createSource() -> String {
    """
    
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void renderImage(
      constant uint *frameID [[buffer(0)]],
      texture2d<half, access::write> drawableTexture [[texture(0)]],
      ushort2 tid [[thread_position_in_grid]]
    ) {
      half4 color;
      if (tid.x == tid.y || tid.x == 1920 - tid.y) {
        color = half4(0.00, 0.00, 0.00, 1.00);
      } else {
        uint frameModulo = *frameID % 120;
        half frameNormalized = half(frameModulo) / 120;
        color = half4(frameNormalized, 0.00, 0.00, 1.00);
      }
    
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

// MARK: - AAPLResponder

// For now, the responder simply coordinates the shutdown of the application.
// It automatically registers a shutdown event when the user pressed the
// "X" button. For the Cmd + W modifier, we have to code this explicitly.
//
// As we build up more low-level UI event handling capabilities, we'll expand
// this to responding to more keys. And eventually mouse movements. All sent
// asynchronously with atomics. 'MolecularRenderer' should only encapsulate
// the Mac and Windows low-level infrastructure for attaining UI events. The
// actual GUI implementation should be deferred to a calling library.
class AAPLResponder: NSResponder {
  func registerResponses(window: NSWindow) {
    // Register to be notified when the window closes.
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(windowWillClose(notification:)),
      name: NSWindow.willCloseNotification,
      object: window)
  }
  
  @objc
  func windowWillClose(notification: NSNotification) {
    exit(0)
  }
  
  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      switch event.charactersIgnoringModifiers! {
      case "w":
        exit(0)
      default:
        break
      }
    }
  }
}

// MARK: - Launching the Application

// Initialize the rendering resources.
let appDelegate = AAPLAppDelegate()

// Keep the renderer alive while the app runs.
withExtendedLifetime(appDelegate) {
  // Set up the application.
  let app = NSApplication.shared
  app.delegate = appDelegate
  guard app.setActivationPolicy(.regular) else {
    fatalError("Failed to set activation policy.")
  }
  app.activate(ignoringOtherApps: true)
  
  // Launch the application.
  app.run()
}
