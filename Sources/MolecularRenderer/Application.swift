import AppKit

public struct ApplicationDescriptor {
  public var display: Display?
  public var gpuContext: GPUContext?
  
  public init() {
    
  }
}

public class Application {
  public var clock: Clock
  public var display: Display
  public var gpuContext: GPUContext
  var view: View
  var window: Window
  
  public init(descriptor: ApplicationDescriptor) {
    guard let display = descriptor.display,
          let gpuContext = descriptor.gpuContext else {
      fatalError("Descriptor was incomplete.")
    }
    self.display = display
    self.gpuContext = gpuContext
    
    clock = Clock()
    view = View(display: display)
    window = Window(display: display)
    
    window.view = view
  }
  
  public func run(
    _ runLoop: @escaping (MTLTexture) -> Void
  ) {
    // Use CVDisplayLink to facilitate the run loop.
    var displayLink: CVDisplayLink!
    let screenID = display.screenID
    CVDisplayLinkCreateWithCGDisplay(UInt32(screenID), &displayLink)
    CVDisplayLinkSetOutputHandler(displayLink) {
      [self] displayLink, now, outputTime, _, _ in
      
      // Check that the screen is valid.
      window.checkScreen(displayLink: displayLink)
      
      // Retrieve the framebuffer.
      let drawable = view.metalLayer.nextDrawable()
      guard let drawable else {
        fatalError("Drawable timed out after 1 second.")
      }
      
      // Invoke the user-supplied closure.
      runLoop(drawable.texture)
      
      // Present the framebuffer.
      do {
        let commandBuffer = gpuContext.commandQueue.makeCommandBuffer()!
        commandBuffer.present(drawable)
        commandBuffer.commit()
      }
      
      // Return an error code indicating success.
      return kCVReturnSuccess
    }
    CVDisplayLinkStart(displayLink)
    
    // Launch the UI window with NSApplication.
    let application = NSApplication.shared
    application.delegate = window
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    application.run()
  }
}
