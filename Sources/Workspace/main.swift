// Next steps:
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible. [DONE]
//   - Get timestamps synchronizing properly (moving rainbow banner
//     scene).
// - Repeat the same process with COM / D3D12 on Windows.
//   - Another single-file Swift script that does the same thing.

import AppKit

// MARK: - Screen

struct Screen {
  static var desired: NSScreen {
    let screens = NSScreen.screens
    let fastest = screens.max(by: {
      $0.maximumFramesPerSecond < $1.maximumFramesPerSecond
    })!
    return fastest
  }
  
  static var renderTargetSize: Int {
    1920
  }
  
  static var backingScaleFactor: Float {
    var scaleFactors: [Float] = []
    for screen in NSScreen.screens {
      let scaleFactor = screen.backingScaleFactor
      scaleFactors.append(Float(scaleFactor))
    }
    
    if scaleFactors.count > 1 {
      let allAreEqual = scaleFactors.allSatisfy { scaleFactor in
        let expected = scaleFactors[0]
        return scaleFactor == expected
      }
      guard allAreEqual else {
        fatalError("Scale factors were not consistent across displays.")
      }
    }
    return scaleFactors[0]
  }
}

// MARK: - Renderer

class Renderer {
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var computePipelineState: MTLComputePipelineState
  
  var startDate: Date?
  var startContinuousTime: UInt64?
  
  init() {
    device = MTLCreateSystemDefaultDevice()!
    commandQueue = device.makeCommandQueue()!
    computePipelineState = Renderer
      .createComputePipelineState(device: device)
  }
  
  func render(
    layer: CAMetalLayer,
    now: CVTimeStamp,
    outputTime: CVTimeStamp
  ) {
    // Update the time.
    if startDate == nil {
      startDate = Date()
    }
    if startContinuousTime == nil {
      startContinuousTime = mach_continuous_time()
    }
    
    // Fetch the drawable.
    let drawable = layer.nextDrawable()
    guard let drawable else {
      fatalError("Drawable timed out after 1 second.")
    }
    
    // Start the command buffer.
    let commandBuffer = commandQueue.makeCommandBuffer()!
    let encoder = commandBuffer.makeComputeCommandEncoder()!
    encoder.setComputePipelineState(computePipelineState)
    
    // Bind the arguments.
    func setTime(_ time: Double, index: Int) {
      let fractionalTime = time - floor(time)
      var time32 = Float(fractionalTime)
      encoder.setBytes(&time32, length: 4, index: index)
    }
    do {
      let currentDate = Date()
      let deltaDate = currentDate.timeIntervalSince(startDate!)
      setTime(deltaDate, index: 0)
    }
    do {
      let currentContinuousTime = mach_continuous_time()
      let deltaContinuousTime = currentContinuousTime - startContinuousTime!
      let deltaContinuousTimeSeconds = Double(deltaContinuousTime) / 24_000_000
      setTime(deltaContinuousTimeSeconds, index: 1)
    }
    do {
      setTime(Double.zero, index: 2)
    }
    encoder.setTexture(drawable.texture, index: 0)
    
    // Dispatch.
    let dispatchSize = Screen.renderTargetSize
    encoder.dispatchThreads(
      MTLSize(width: dispatchSize, height: dispatchSize, depth: 1),
      threadsPerThreadgroup: MTLSize(width: 8, height: 8, depth: 1))
    
    // Finish the command buffer.
    encoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
}

extension Renderer {
  static func createSource() -> String {
    """
    
    #include <metal_stdlib>
    using namespace metal;
    
    half convertToChannel(
      half hue,
      half saturation, 
      half lightness,
      ushort n
    ) {
      half k = half(n) + hue / 30;
      k -= 12 * floor(k / 12);
      
      half a = saturation;
      a *= min(lightness, 1 - lightness);
    
      half output = min(k - 3, 9 - k);
      output = max(output, half(-1));
      output = min(output, half(1));
      output = lightness - a * output;
      return output;
    }
    
    kernel void renderImage(
      constant float *time0 [[buffer(0)]],
      constant float *time1 [[buffer(1)]],
      constant float *time2 [[buffer(2)]],
      texture2d<half, access::write> drawableTexture [[texture(0)]],
      ushort2 tid [[thread_position_in_grid]]
    ) {
      half4 color;
      if (tid.y < 1600) {
        color = half4(0.707, 0.707, 0.00, 1.00);
      } else {
        float progress = float(tid.x) / 1920;
        if (tid.y < 1600 + 107) {
          progress += *time0;
        } else if (tid.y < 1600 + 213) {
          progress += *time1;
        } else {
          progress += *time2;
        }
        
        half hue = half(progress) * 360;
        half saturation = 1.0;
        half lightness = 0.5;
        
        half red = convertToChannel(hue, saturation, lightness, 0);
        half green = convertToChannel(hue, saturation, lightness, 8);
        half blue = convertToChannel(hue, saturation, lightness, 4);
        color = half4(red, green, blue, 1.00);
      }
      
      drawableTexture.write(color, tid);
    }
    
    """
  }
  
  static func createComputePipelineState(
    device: MTLDevice
  ) -> MTLComputePipelineState {
    let shaderSource = Renderer.createSource()
    let library = try! device.makeLibrary(source: shaderSource, options: nil)
    
    let function = library.makeFunction(name: "renderImage")
    guard let function else {
      fatalError("Could not make function.")
    }
    let pipeline = try! device.makeComputePipelineState(function: function)
    return pipeline
  }
}

// MARK: - RendererView

class RendererView: NSView, CALayerDelegate {
  var displayLink: CVDisplayLink!
  var metalLayer: CAMetalLayer!
  var renderer: Renderer!
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    self.layerContentsRedrawPolicy = .duringViewResize
    self.wantsLayer = true
    metalLayer = self.layer! as? CAMetalLayer
    
    let renderTargetSize = Float(Screen.renderTargetSize)
    let windowSize = renderTargetSize / Screen.backingScaleFactor
    metalLayer.drawableSize = CGSize(
      width: Double(renderTargetSize),
      height: Double(renderTargetSize))
    
    metalLayer.delegate = self
    self.bounds.size = CGSize(
      width: Double(windowSize),
      height: Double(windowSize))
    self.frame.size = CGSize(
      width: Double(windowSize),
      height: Double(windowSize))
    
    metalLayer.device = MTLCreateSystemDefaultDevice()!
    metalLayer.framebufferOnly = false
    metalLayer.pixelFormat = .rgb10a2Unorm
    
    renderer = Renderer()
  }
  
  override func makeBackingLayer() -> CALayer {
    let layer = CAMetalLayer()
    return layer
  }
  
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    
    let screen = Screen.desired
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    let screenNumberAny = screen.deviceDescription[key]!
    let screenNumber = screenNumberAny as! NSNumber
    CVDisplayLinkCreateWithCGDisplay(screenNumber.uint32Value, &displayLink)
    CVDisplayLinkSetOutputHandler(displayLink) {
      [self] displayLink, now, outputTime, _, _ in
      
      renderer.render(
        layer: metalLayer,
        now: now.pointee,
        outputTime: outputTime.pointee)
      
      return kCVReturnSuccess
    }
    CVDisplayLinkStart(displayLink)
  }
}

extension RendererView {
  func checkDrawableSize(_ newSize: NSSize) {
    var expectedSize = Float(Screen.renderTargetSize)
    expectedSize /= Screen.backingScaleFactor
    
    let width = Float(newSize.width)
    let height = Float(newSize.height)
    guard width == expectedSize,
          height == expectedSize else {
      fatalError("Not allowed to resize window.")
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

// MARK: - RendererViewController

class RendererViewController: NSViewController, NSApplicationDelegate {
  var window: NSWindow!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    let view = RendererView()
    self.view = view
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    window = NSWindow(
      contentRect: NSRect.zero,
      styleMask: [.closable, .resizable, .titled],
      backing: .buffered,
      defer: false,
      screen: Screen.desired)
    window.makeFirstResponder(self)
    window.contentViewController = self
    
    // 'window.center' forces the window to initially appear on the main
    // display.
    window.center()
    window.makeKey()
    window.orderFrontRegardless()
    
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
}

extension RendererViewController {
  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      let characters = event.charactersIgnoringModifiers!
      if characters == "w" {
        exit(0)
      }
    }
  }
}

// MARK: - RendererApplication

class RendererApplication {
  var viewController: RendererViewController
  
  init() {
    viewController = RendererViewController()
  }
  
  func launch() {
    let app = NSApplication.shared
    app.delegate = viewController
    app.setActivationPolicy(.regular)
    app.activate(ignoringOtherApps: true)
    app.run()
  }
}

let app = RendererApplication()
app.launch()
