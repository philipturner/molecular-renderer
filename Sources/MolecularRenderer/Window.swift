import AppKit

class Window: NSViewController, NSApplicationDelegate {
  var displayLink: CVDisplayLink!
  var window: NSWindow
  var windowSize: Int
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    // Initialize the display link.
    do {
      let screenID = display.screenID
      CVDisplayLinkCreateWithCGDisplay(UInt32(screenID), &displayLink)
    }
    
    // Initialize the window.
    do {
      let screenID = display.screenID
      let screen = Display.screen(screenID: screenID)
      window = NSWindow(
        contentRect: NSRect.zero,
        styleMask: [.closable, .resizable, .titled],
        backing: .buffered,
        defer: false,
        screen: screen)
    }
    
    // Prepare the window's bounds.
    do {
      let origin = Window.centeredOrigin(display: display)
      window.setFrameOrigin(origin)
      windowSize = display.windowSize
    }
    
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
//
// Using the original specified display instead of the value returned
// by 'CVDisplayLinkGetCurrentCGDisplay'. That way, if the CVDisplayLink
// bug is fixed, we still have the same behavior.
extension Window {
  func checkScreen(expectedID: Int) {
    // Access the NSWindow on the main queue to prevent a crash.
    DispatchQueue.main.async { [self] in
      let screen = window.screen!
      let actualID = Display.screenID(screen: screen)
      if actualID != expectedID {
        fatalError("Attempted to move the window to a different display.")
      }
    }
  }
}
