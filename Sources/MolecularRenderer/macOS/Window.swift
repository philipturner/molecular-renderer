#if os(macOS)
import AppKit

class Window: NSViewController, NSApplicationDelegate {
  nonisolated(unsafe) var nsWindow: NSWindow
  var windowSize: SIMD2<Int>
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    // Initialize the window.
    nsWindow = NSWindow(
      contentRect: NSRect.zero,
      styleMask: [.closable, .titled],
      backing: .buffered,
      defer: false,
      screen: display.nsScreen)
    
    // Prepare the window's bounds.
    let origin = Window.centeredOrigin(display: display)
    nsWindow.setFrameOrigin(origin)
    windowSize = display.windowSize
    
    super.init(nibName: nil, bundle: nil)
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register the UI event handlers.
    nsWindow.makeFirstResponder(self)
    registerCloseNotification()
    
    // Initialize the window's dimensions (which are slightly larger than the
    // render target).
    nsWindow.contentViewController = self
    guard nsWindow.frame.size.width == Double(windowSize[0]) else {
      fatalError("Window had incorrect size.")
    }
    guard nsWindow.frame.size.height > Double(windowSize[1]) else {
      fatalError("Title bar was missing.")
    }
    
    // Make the window visible to the user.
    nsWindow.makeKey()
    nsWindow.orderFrontRegardless()
  }
}

extension Window {
  static func centeredOrigin(display: Display) -> CGPoint {
    let center = SIMD2<Double>(
      display.nsScreen.visibleFrame.midX,
      display.nsScreen.visibleFrame.midY)
    
    let upperLeft = center - SIMD2<Double>(display.windowSize) / 2
    return CGPoint(
      x: upperLeft[0],
      y: upperLeft[1])
  }
  
  func registerCloseNotification() {
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(windowWillClose(notification:)),
      name: NSWindow.willCloseNotification,
      object: nsWindow)
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
}

#endif
