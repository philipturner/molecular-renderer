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
    
    clock = Clock(display: display)
    view = View(display: display)
    window = Window(display: display)
    
    window.view = view
  }
  
  public func run(
    _ closure: @escaping (MTLTexture) -> Void
  ) {
    var runLoopDesc = RunLoopDescriptor()
    runLoopDesc.application = self
    runLoopDesc.closure = closure
    
    let runLoop = RunLoop(descriptor: runLoopDesc)
    withExtendedLifetime(runLoop) {
      // Launch the UI window with NSApplication.
      let application = NSApplication.shared
      application.delegate = window
      application.setActivationPolicy(.regular)
      application.activate(ignoringOtherApps: true)
      application.run()
    }
  }
}
