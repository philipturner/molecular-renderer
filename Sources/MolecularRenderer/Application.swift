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
  }
  
  public func run() {
    let application = NSApplication.shared
    application.delegate = window
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    
    setOutputHandler(window.displayLink)
    CVDisplayLinkStart(window.displayLink)
    application.run()
  }
}

extension Application {
  func setOutputHandler(_ displayLink: CVDisplayLink) {
    // Set the function pointer for the render loop.
    CVDisplayLinkSetOutputHandler(displayLink) {
      [self] displayLink, now, outputTime, _, _ in
      
      // Check that the correct screen is linked.
      let expectedID = display.screenID
      window.checkScreen(expectedID: expectedID)
      
      // Fetch the drawable.
      let layer = view.metalLayer
      let drawable = layer.nextDrawable()
      guard let drawable else {
        fatalError("Drawable timed out after 1 second.")
      }
      
      // Start the command buffer.
      let commandBuffer = renderer.commandQueue.makeCommandBuffer()!
      let encoder = commandBuffer.makeComputeCommandEncoder()!
      
      renderer.render(
        encoder: encoder,
        renderTarget: drawable.texture)
      
      // Finish the command buffer.
      encoder.endEncoding()
      commandBuffer.present(drawable)
      commandBuffer.commit()
      
      // Return an error code indicating success.
      return kCVReturnSuccess
    }
  }
}
