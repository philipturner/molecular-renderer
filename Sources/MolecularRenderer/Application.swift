import AppKit

public struct ApplicationDescriptor {
  public var display: Display?
  
  public init() {
    
  }
}

public class Application {
  public var clock: Clock
  public var display: Display
  var renderer: Renderer
  var view: View
  var window: Window
  
  var displayLink: CVDisplayLink
  
  public init(descriptor: ApplicationDescriptor) {
    guard let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    self.display = display
    
    clock = Clock()
    renderer = Renderer()
    view = View(display: display)
    window = Window(display: display)
    
    window.view = view
    
    // TODO: Wrap this code in something cleaner.
    displayLink = Application.createDisplayLink(display: display)
    setOutputHandler(displayLink)
    CVDisplayLinkStart(displayLink)
  }
  
  public func run() {
    let application = NSApplication.shared
    application.delegate = window
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    application.run()
  }
}

extension Application {
  static func createDisplayLink(display: Display) -> CVDisplayLink {
    var displayLink: CVDisplayLink!
    
    // Initialize the display link with the chosen screen.
    let screenNumber = Display.screenNumber(screen: display.screen)
    CVDisplayLinkCreateWithCGDisplay(screenNumber, &displayLink)
    
    return displayLink
  }
  
  func setOutputHandler(_ displayLink: CVDisplayLink) {
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
      
      // Using the original specified display instead of the value returned
      // by 'CVDisplayLinkGetCurrentCGDisplay'. That way, if the CVDisplayLink
      // bug is fixed, we still have the same behavior.
      let registeredDisplay = Display.screenNumber(screen: display.screen)
      
      // Access the window on the main queue to prevent a crash.
      DispatchQueue.main.async { [self] in
        let screen = window.window.screen!
        
        let actualDisplay = Display.screenNumber(screen: screen)
        if registeredDisplay != actualDisplay {
          fatalError("Attempted to move the window to a different display.")
        }
      }
      
      
      renderer.render(layer: view.metalLayer)
      
      // Return an error code indicating success.
      return kCVReturnSuccess
    }
  }
}
