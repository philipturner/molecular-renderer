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
  // The screen chosen for rendering at program startup.
  static let selected: NSScreen = {
    let screens = NSScreen.screens
    let fastest = screens.max(by: {
      $0.maximumFramesPerSecond < $1.maximumFramesPerSecond
    })!
    return fastest
  }()
  
  // The view resolution chosen at program startup.
  static var renderTargetSize: Int {
    1920
  }
  
  // The resolution of the rendering region, according to the OS's display
  // scaling factor.
  static var windowSize: Int {
    var output = Double(renderTargetSize)
    output /= Screen.selected.backingScaleFactor
    guard output == floor(output) else {
      fatalError("Resolution was not evenly divisible by scaling factor.")
    }
    return Int(output)
  }
}

// MARK: - Time

struct TimeStamp {
  // The Mach continuous time for now.
  var host: UInt64
  
  // The Core Video time for when the frame will be presented.
  var video: CVTimeStamp
}

class TimeCounter {
  private var start: TimeStamp?
  private var previous: TimeStamp?
  private var current: TimeStamp?
  
  init() {
    
  }
  
  func increment(vsyncFrameIndex: CVTimeStamp) {
    let currentHostTime = mach_continuous_time()
    let currentTimeStamp = TimeStamp(
      host: currentHostTime,
      video: vsyncFrameIndex)
    
    // TODO: The names of the variables are getting ambiguous here. It's hard
    // to clean up this code and make progress on it.
    if let start = start,
       let previousTimeStamp = current {
      self.start = start
      self.previous = previous
      self.current = currentTimeStamp
    } else {
      self.start = currentTimeStamp
      self.previous = nil
      self.current = currentTimeStamp
    }
    
    guard let start,
          let current else {
      fatalError("Invalid time counter state.")
    }
    
    // Validate that the vsync frame index is an integer multiple.
  }
}

// MARK: - Renderer

class Renderer {
  var device: MTLDevice
  var commandQueue: MTLCommandQueue
  var computePipelineState: MTLComputePipelineState
  
  init() {
    device = MTLCreateSystemDefaultDevice()!
    commandQueue = device.makeCommandQueue()!
    computePipelineState = Renderer
      .createComputePipelineState(device: device)
  }
  
  // Commented out reference code.
  /*
  func registerFrameStart(
    now: CVTimeStamp,
    outputTime: CVTimeStamp
  ) {
    if startDate == nil {
      startDate = Date()
    }
    if startContinuousTime == nil {
      startContinuousTime = mach_continuous_time()
    }
    if startTimeStamp == nil {
      startTimeStamp = outputTime
    }
    currentVideoTime = outputTime
    
    let currentTimeStamp = outputTime
    let currentTimeTicks: Int64 = 
    currentTimeStamp.videoTime - startTimeStamp!.videoTime
    let currentTimeSeconds = Double(currentTimeTicks) / 24_000_000
    
    let frameRate: Int = Screen.selected.maximumFramesPerSecond
    let currentTimeFrames = currentTimeSeconds * Double(frameRate)
    let roundedTimeFrames = rint(currentTimeFrames)
    let remainderTimeFrames = currentTimeFrames - roundedTimeFrames
    guard remainderTimeFrames.magnitude < 0.001 else {
      fatalError(
        "Timestamp was not integer multiple of refresh rate: \(currentTimeFrames).")
    }
    
    // Bring into alignment with the wall clock time.
    let currentContinuousTime = mach_continuous_time()
    let wallTime = currentContinuousTime - startContinuousTime!
    let wallTimeSeconds = Double(wallTime) / 24_000_000
    let wallTimeFrames = wallTimeSeconds * Double(frameRate)
    print(wallTimeFrames, roundedTimeFrames)
    
    currentFrameID = Int(roundedTimeFrames)
  }
  
  func registerFrameEnd(
    now: CVTimeStamp,
    outputTime: CVTimeStamp
  ) {
    previousVideoTime = currentVideoTime
    currentVideoTime = nil
  }
   */
  
  func render(
    layer: CAMetalLayer
  ) {
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
    
    // Commented out reference code.
    /*
    print()
    do {
      let currentDate = Date()
      let deltaDate = currentDate.timeIntervalSince(startDate!)
      print(deltaDate, deltaDate * 120)
      setTime(deltaDate, index: 0)
    }
    do {
      let currentContinuousTime = mach_continuous_time()
      let deltaContinuousTime = currentContinuousTime - startContinuousTime!
      let deltaContinuousTimeSeconds = Double(deltaContinuousTime) / 24_000_000
      print(deltaContinuousTimeSeconds, deltaContinuousTimeSeconds * 120)
      setTime(deltaContinuousTimeSeconds, index: 1)
    }
    do {
      let currentTimeStamp = outputTime
      let currentTime = currentTimeStamp.hostTime - startTimeStamp!.hostTime
      let currentTimeSeconds = Double(currentTime) / 24_000_000
      print(currentTimeSeconds, currentTimeSeconds * 120)
    }
    do {
      let currentTimeStamp = outputTime
      let currentTime = currentTimeStamp.videoTime - startTimeStamp!.videoTime
      let currentTimeSeconds = Double(currentTime) / 24_000_000
      print(currentTimeSeconds, currentTimeSeconds * 120)
      setTime(currentTimeSeconds, index: 2)
    }
     */
    
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
    metalLayer.drawableSize = CGSize(
      width: Double(Screen.renderTargetSize),
      height: Double(Screen.renderTargetSize))
    
    metalLayer.delegate = self
    
    var windowSize = Double(Screen.renderTargetSize)
    windowSize /= Screen.selected.backingScaleFactor
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
    
    // Initialize the display link with the chosen screen.
    let key = NSDeviceDescriptionKey("NSScreenNumber")
    let screenNumberAny = Screen.selected.deviceDescription[key]!
    let screenNumber = screenNumberAny as! NSNumber
    CVDisplayLinkCreateWithCGDisplay(screenNumber.uint32Value, &displayLink)
    
    // Set the function pointer for the render loop.
    CVDisplayLinkSetOutputHandler(displayLink) {
      [self] displayLink, now, outputTime, _, _ in
      
      // There is a bug where CVDisplayLink doesn't register transitions to an
      // external display. We detect this bug by first
      // querying the screen of the 'NSWindow'. Then, comparing it to the
      // screen from 'CVDisplayLinkGetCurrentCGDisplay'. The latter is always
      // the same as the screen it was initialized with (which is the bug).
      // The app crashes upon realizing that the correct screen does not match
      // what CVDisplayLink thinks the screen is.
      //
      // The fix does not solve the issues with Vsync on macOS:
      // https://thume.ca/2017/12/09/cvdisplaylink-doesnt-link-to-your-display/
      //
      // But it is important for the error correction scheme for frame
      // misalignment. Previously, it was only parameterized for 120 Hz
      // displays, where the app might become unstable on the 60 Hz monitor.
      // With the intentional crashing, I removed the need for the heuristic
      // to handle display transitions. It is one display throughout the
      // entire session, whose framerate is known a priori. Apparently Vsync
      // is much better on Windows, so I will not/should not apply the
      // heuristic there.
      let registeredDisplay = CVDisplayLinkGetCurrentCGDisplay(displayLink)
      DispatchQueue.main.async {
        let window = RendererViewController.globalWindowReference
        guard let window else {
          fatalError("Could not retrieve window.")
        }
        let screen = window.screen!
        
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let screenNumberAny = screen.deviceDescription[key]!
        let screenNumber = screenNumberAny as! NSNumber
        let actualDisplay = screenNumber.uint32Value
        
        if registeredDisplay != actualDisplay {
          fatalError("Attempted to move the window to a different display.")
        }
      }
      
      renderer.render(
        layer: metalLayer,
        now: now.pointee,
        outputTime: outputTime.pointee)
      
      return kCVReturnSuccess
    }
    
    // Start the display link.
    CVDisplayLinkStart(displayLink)
  }
}

extension RendererView {
  func checkDrawableSize(_ newSize: NSSize) {
    guard newSize.width == Double(Screen.windowSize),
          newSize.height == Double(Screen.windowSize) else {
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

// MARK: - RendererViewController

class RendererViewController: NSViewController, NSApplicationDelegate {
  var window: NSWindow!
  
  static var globalWindowReference: NSWindow?
  
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
      screen: Screen.selected)
    RendererViewController.globalWindowReference = window
    
    window.makeFirstResponder(self)
    window.contentViewController = self
    
    RendererViewController.centerWindow(window)
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
  
  // An alternative to 'NSWindow.center()' that doesn't make the window migrate
  // to the main display.
  static func centerWindow(_ window: NSWindow) {
    guard let screen = window.screen else {
      fatalError("Could not retrieve the window's screen.")
    }
    let centerX = screen.visibleFrame.midX
    let centerY = screen.visibleFrame.midY
    let scaleFactor = screen.backingScaleFactor
    
    let renderRegionSize = Double(Screen.renderTargetSize) / scaleFactor
    let leftX = centerX - renderRegionSize / 2
    let upperY = centerY - renderRegionSize / 2
    let origin = CGPoint(x: leftX, y: upperY)
    
    let windowSize = window.frame.size
    guard windowSize.width == renderRegionSize else {
      fatalError("Render region had incorrect dimensions.")
    }
    guard windowSize.height > renderRegionSize else {
      fatalError("Title bar was missing.")
    }
    
    let frame = CGRect(origin: origin, size: windowSize)
    window.setFrame(frame, display: true)
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
