import AppKit

class Window: NSViewController, NSApplicationDelegate {
  unowned var display: Display
  var window: NSWindow
  
  init(display: Display) {
    self.display = display
    window = NSWindow(
      contentRect: NSRect.zero,
      styleMask: [.closable, .resizable, .titled],
      backing: .buffered,
      defer: false,
      screen: display.screen)
    
    super.init(nibName: nil, bundle: nil)
  }
  
  required init(coder: NSCoder) {
    fatalError("Not implemented.")
  }
}

extension Window {
  func applicationDidFinishLaunching(_ notification: Notification) {
    window.makeFirstResponder(self)
    window.contentViewController = self
    
    Window.center(window: window, display: display)
    window.makeKey()
    window.orderFrontRegardless()
    
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      self,
      selector: #selector(windowWillClose(notification:)),
      name: NSWindow.willCloseNotification,
      object: window)
  }
  
  // An alternative to 'NSWindow.center()' that doesn't make the window migrate
  // to the main display.
  //
  // TODO: Try forcing these bounds to be set during the initializer.
  static func center(window: NSWindow, display: Display) {
    guard let screen = window.screen else {
      fatalError("Could not retrieve the window's screen.")
    }
    let centerX = screen.visibleFrame.midX
    let centerY = screen.visibleFrame.midY
    let scaleFactor = screen.backingScaleFactor
    
    let renderRegionSize = Double(display.renderTargetSize) / scaleFactor
    let leftX = centerX - renderRegionSize / 2
    let upperY = centerY - renderRegionSize / 2
    let origin = CGPoint(x: leftX, y: upperY)
    
    let windowSize = window.frame.size
    guard windowSize.width == renderRegionSize else {
      fatalError("Render region had incorrect dimensions..")
    }
    guard windowSize.height > renderRegionSize else {
      fatalError("Title bar was missing.")
    }
    
    let frame = CGRect(origin: origin, size: windowSize)
    window.setFrame(frame, display: true)
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

#if false
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
#endif
