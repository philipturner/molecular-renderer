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
  
  @MainActor
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
  
  @MainActor
  public func run(
    _ closure: @escaping (MTLTexture) -> Void
  ) {
    var runLoopDesc = RunLoopDescriptor()
    runLoopDesc.application = self
    runLoopDesc.closure = closure
    
    let runLoop = RunLoop(descriptor: runLoopDesc)
    runLoop.start()
    
    // WARNING: Do not launch the application from the Xcode UI on macOS 15.
    // There is a bug that makes it launch the application 3 times:
    // https://www.reddit.com/r/Xcode/comments/1g7640w/xcode_starting_running_my_programs_twice/
    // https://developer.apple.com/forums/thread/765445
    //
    // Remedies:
    // - Unchecking 'debug executable' in the Xcode scheme for 'Workspace':
    //   - Reduces the number of launches from 3 to 2.
    // - Delaying with sleep:
    //   - sleep(1) from the forums is 1 s (1000 ms), an incredibly large delay.
    //     Duplicated windows stop appearing once the delay approaches ~350 ms
    //     on my machine. Use usleep(400_000) for 400 ms delay, or refine to
    //     50 ms above the value that consistently works on your machine.
    // - Switching to release mode in the Xcode scheme for 'Workspace':
    //   - The number of launches is still 3.
    // - Only launching from a SwiftPM console workflow ('swift run'):
    //   - Effectively solves the problem.
    //
    // Can you auto-detect whether it's being launched from SwiftPM?
    //
    // No.
    
    let application = NSApplication.shared
    application.delegate = window
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    application.run()
    
    runLoop.stop()
  }
}
