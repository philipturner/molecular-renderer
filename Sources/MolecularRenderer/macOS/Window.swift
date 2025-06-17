#if os(macOS)
import AppKit

class Window: NSViewController, NSApplicationDelegate {
  nonisolated(unsafe) var nsWindow: NSWindow
  
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
    
    /*
    // Prepare the window's bounds.
    let origin = Window.centeredOrigin(display: display)
    let originPoint = CGPoint(
      x: origin[0],
      y: origin[1])
    nsWindow.setFrameOrigin(originPoint)
    windowSize = display.windowSize
     */
    
    let workArea = display.nsScreen.visibleFrame
    let workAreaCenter = SIMD2<Double>(workArea.midX, workArea.midY)
    let contentSize = display.contentSize
    let contentBottomLeft = workAreaCenter - contentSize / 2
    
    let contentRect = NSRect(
      origin: CGPointMake(contentBottomLeft[0], contentBottomLeft[1]),
      size: CGSizeMake(contentSize[0], contentSize[1]))
    let frameRect = nsWindow.frameRect(forContentRect: contentRect)
    nsWindow.setFrameOrigin(frameRect.origin)
    
    print(workArea)
    print(workAreaCenter)
    print(contentSize)
    print(contentBottomLeft)
    print(contentRect)
    print(frameRect)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  // The content rect is set by the OS, between initialization and the call to
  // this function.
  func applicationDidFinishLaunching(_ notification: Notification) {
    // Register the UI event handlers.
    nsWindow.makeFirstResponder(self)
    registerCloseNotification()
    
    print("nsWindow.frame:", nsWindow.frame)
    nsWindow.contentViewController = self
    print("nsWindow.frame:", nsWindow.frame)
    
    /*
    // Initialize the window's dimensions (which are slightly larger than the
    // render target).
    nsWindow.contentViewController = self
    guard nsWindow.frame.size.width == Double(windowSize[0]) else {
      fatalError("Window had incorrect size.")
    }
    guard nsWindow.frame.size.height > Double(windowSize[1]) else {
      fatalError("Title bar was missing.")
    }
     */
    
    // Make the window visible to the user.
    nsWindow.makeKey()
    nsWindow.orderFrontRegardless()
  }
}

extension Window {
  /*
  static func centeredOrigin(display: Display) -> SIMD2<Double> {
    let workArea = Display.workArea(
      screen: display.nsScreen)
    
    let center = (
      SIMD2<Double>(workArea.lowHalf) +
      SIMD2<Double>(workArea.highHalf)
    ) / 2
    
    let upperLeft = center - SIMD2<Double>(display.windowSize) / 2
    
    return upperLeft
  }
   */
  
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
