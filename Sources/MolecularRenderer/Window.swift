import AppKit

class Window: NSViewController, NSApplicationDelegate {
  nonisolated(unsafe) var window: NSWindow
  var windowSize: Int
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    // Initialize the window.
    let screenID = display.screenID
    let screen = Display.screen(screenID: screenID)
    window = NSWindow(
      contentRect: NSRect.zero,
      styleMask: [.closable, .resizable, .titled],
      backing: .buffered,
      defer: false,
      screen: screen)
    
    // Prepare the window's bounds.
    let origin = Window.centeredOrigin(display: display)
    window.setFrameOrigin(origin)
    windowSize = display.windowSize
    
    super.init(nibName: nil, bundle: nil)
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register the UI event handlers.
    window.makeFirstResponder(self)
    registerCloseNotification()
    
    // Initialize the window's dimensions (which are slightly larger than the
    // render target).
    window.contentViewController = self
    guard window.frame.size.width == Double(windowSize) else {
      fatalError("Window had incorrect size.")
    }
    guard window.frame.size.height > Double(windowSize) else {
      fatalError("Title bar was missing.")
    }
    
    // Make the window visible to the user.
    window.makeKey()
    window.orderFrontRegardless()
  }
}

extension Window {
  static func centeredOrigin(display: Display) -> CGPoint {
    let screenID = display.screenID
    let screen = Display.screen(screenID: screenID)
    
    let centerX = screen.visibleFrame.midX
    let centerY = screen.visibleFrame.midY
    let leftX = centerX - Double(display.windowSize) / 2
    let upperY = centerY - Double(display.windowSize) / 2
    let origin = CGPoint(x: leftX, y: upperY)
    return origin
  }
  
  func registerCloseNotification() {
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
}
