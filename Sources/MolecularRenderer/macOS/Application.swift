#if os(macOS)
import AppKit

public struct ApplicationDescriptor {
  public var device: Device?
  public var display: Display?
  
  public init() {
    
  }
}

public class Application {
  public var clock: Clock
  public let device: Device
  public let display: Display
  let view: View
  let window: Window
  
  @MainActor
  public init(descriptor: ApplicationDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    self.device = device
    self.display = display
    
    clock = Clock(display: display)
    view = View(display: display)
    window = Window(display: display)
    
    window.view = view
  }
  
  /// Only call this one time after the application is created.
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
    
    print("starting...")
    let application = NSApplication.shared
    application.delegate = window
    application.setActivationPolicy(.regular)
    application.activate(ignoringOtherApps: true)
    application.run()
    print("stopping...")
    
    // This is needed. On some app launches, it makes no difference. On others,
    // the output handler is called dozens of times after the NSApplication
    // stops running.
    runLoop.stop()
  }
}

#endif
