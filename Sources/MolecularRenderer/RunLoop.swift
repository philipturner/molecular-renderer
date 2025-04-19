import AppKit
import QuartzCore

struct RunLoopDescriptor {
  var application: Application?
  var closure: ((MTLTexture) -> Void)?
}

class RunLoop {
  unowned let application: Application
  var closure: (MTLTexture) -> Void
  var displayLink: CVDisplayLink?
  
  init(descriptor: RunLoopDescriptor) {
    guard let application = descriptor.application,
          let closure = descriptor.closure else {
      fatalError("Descriptor was incomplete.")
    }
    self.application = application
    self.closure = closure
    
    // Fetching the screen.
    let screenID = application.display.screenID
    
    // Old method for initializing the display link.
    CVDisplayLinkCreateWithCGDisplay(UInt32(screenID), &displayLink)
    CVDisplayLinkSetOutputHandler(displayLink!, outputHandler)
    CVDisplayLinkStart(displayLink!)
    
    // New method for initializing the display link.
    let screen = Display.screen(screenID: screenID)
//    NSScreen.displayLink(target: 2 as Any, selector: outputHandler)
  }
  
  private var outputHandler: CVDisplayLinkOutputHandler {
    {
      [application] displayLink, now, outputTime, flagsIn, flagsOut in
      
      // Increment the frame counter.
      application.clock.increment(
        vsyncTimeStamp: outputTime.pointee)
      
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
      let originalID = application.display.screenID
      let registeredID = Int(CVDisplayLinkGetCurrentCGDisplay(displayLink))
      guard registeredID == originalID else {
        fatalError("The bug's behavior has changed.")
      }
      
      // Access the NSWindow on the main queue to prevent a crash.
      DispatchQueue.main.async {
        let window = application.window.window
        let screen = window.screen!
        let actualID = Display.screenID(screen: screen)
        guard actualID == originalID else {
          fatalError("Attempted to move the window to a different display.")
        }
      }
      
      // Retrieve the framebuffer.
      let layer = application.view.metalLayer
      let drawable = layer.nextDrawable()
      guard let drawable else {
        fatalError("Drawable timed out after 1 second.")
      }
      
      // Invoke the user-supplied closure.
      self.closure(drawable.texture)
      
      // Present the framebuffer.
      let commandQueue = application.gpuContext.commandQueue
      let commandBuffer = commandQueue.makeCommandBuffer()!
      commandBuffer.present(drawable)
      commandBuffer.commit()
      
      return kCVReturnSuccess
    }
  }
}
