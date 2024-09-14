// Next steps:
// - Access the GPU.
//   - Modify it to get Metal rendering. [DONE]
//   - Clean up and simplify the code as much as possible. [DONE]
//   - Get timestamps synchronizing properly (moving rainbow banner
//     scene).
// - Repeat the same process with COM / D3D12 on Windows.
//   - Get some general experience with C++ DirectX sample code.
//   - Modify the files one-by-one to support Windows.

import AppKit
import MolecularRenderer

// MARK: - RendererView

class View: NSView, CALayerDelegate {
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

class Window: NSViewController, NSApplicationDelegate {
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
  
  override func keyDown(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      let characters = event.charactersIgnoringModifiers!
      if characters == "w" {
        exit(0)
      }
    }
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

// MARK: - Application

class Application {
  var clock: Clock
  var display: Display
  var window: Window
  
  init() {
    
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
