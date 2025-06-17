#if os(macOS)
import AppKit

class Window: NSViewController, NSApplicationDelegate {
  nonisolated(unsafe) var nsWindow: NSWindow
  private var frameSize: SIMD2<Double>
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
  
  init(display: Display) {
    // Initialize the window.
    //
    // The content rectangle is set to zero, because its value at this time
    // has no effect on the final value.
    nsWindow = NSWindow(
      contentRect: NSRect.zero,
      styleMask: [.closable, .titled],
      backing: .buffered,
      defer: false,
      screen: display.nsScreen)
    
    let workArea = display.nsScreen.visibleFrame
    let workAreaCenter = SIMD2<Double>(workArea.midX, workArea.midY)
    let contentSize = display.contentSize
    let contentBottomLeft = workAreaCenter - contentSize / 2
    
    let contentRect = NSRect(
      origin: CGPointMake(contentBottomLeft[0], contentBottomLeft[1]),
      size: CGSizeMake(contentSize[0], contentSize[1]))
    let frameRect = nsWindow.frameRect(forContentRect: contentRect)
    nsWindow.setFrameOrigin(frameRect.origin)
    self.frameSize = SIMD2(
      frameRect.size.width,
      frameRect.size.height)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register the UI event handlers.
    nsWindow.makeFirstResponder(self)
    registerCloseNotification()
    
    // Materialize the window's content rect, expanding its frame size to the
    // expected value.
    nsWindow.contentViewController = self
    guard nsWindow.frame.size.width == frameSize[0],
          nsWindow.frame.size.height == frameSize[1] else {
      fatalError("Window had unexpected size.")
    }
    
    // Make the window visible to the user.
    nsWindow.makeKey()
    nsWindow.orderFrontRegardless()
  }
}

extension Window {
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
