#if os(macOS)
import QuartzCore

struct RunLoopDescriptor {
  var closure: ((MTLTexture) -> Void)?
  var display: Display?
}

class RunLoop: @unchecked Sendable {
  let closure: (MTLTexture) -> Void
  var displayLink: CVDisplayLink?
  
  init(descriptor: RunLoopDescriptor) {
    guard let closure = descriptor.closure,
          let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    self.closure = closure
    
    // Initialize the display link.
    let monitorID = Display.number(
      screen: display.nsScreen)
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkCreateWithCGDisplay(UInt32(monitorID), &displayLink)
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkSetOutputHandler(displayLink!, outputHandler)
  }
  
  func start() {
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkStart(displayLink!)
  }
  
  func stop() {
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkStop(displayLink!)
  }
  
  private func outputHandler(
    displayLink: CVDisplayLink,
    now: UnsafePointer<CVTimeStamp>,
    outputTime: UnsafePointer<CVTimeStamp>,
    flagsIn: CVOptionFlags,
    flagsOut: UnsafeMutablePointer<CVOptionFlags>,
  ) -> CVReturn {
    guard let application = Application.singleton else {
      fatalError("Could not retrieve the application.")
    }
    
    // Increment the frame counter.
    application.clock.increment(
      frameStatistics: outputTime.pointee)
    
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
    let originalScreen = application.display.nsScreen
    let originalID = Display.number(screen: originalScreen)
    let registeredID = (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkGetCurrentCGDisplay(displayLink)
    guard registeredID == originalID else {
      fatalError("The bug's behavior has changed.")
    }
    
    // Access the NSWindow on the main queue to prevent a crash.
    let window = application.window.nsWindow
    DispatchQueue.main.async {
      guard let screen = window.screen else {
        fatalError("Failed to retrieve the window's screen.")
      }
      
      let actualID = Display.number(screen: screen)
      guard actualID == originalID else {
        fatalError("Attempted to move the window to a different display.")
      }
    }
    
    // Retrieve the frame buffer.
    let layer = application.view.metalLayer
    let drawable = layer.nextDrawable()
    guard let drawable else {
      fatalError("Drawable timed out after 1 second.")
    }
    
    // Invoke the user-supplied closure.
    self.closure(drawable.texture)
    
    // Present the frame buffer.
    application.device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      commandList.mtlCommandBuffer.present(drawable)
      commandList.mtlCommandEncoder =
        commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    }
    
    return kCVReturnSuccess
  }
}

#endif
