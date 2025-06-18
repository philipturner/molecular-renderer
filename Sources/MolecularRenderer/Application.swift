#if os(macOS)
import AppKit
#else
import SwiftCOM
import WinSDK
#endif

public struct ApplicationDescriptor {
  public var device: Device?
  public var display: Display?
  
  public init() {
    
  }
}

public class Application {
  nonisolated(unsafe) static var singleton: Application?
  var didRun: Bool = false
  
  public let device: Device
  public let display: Display
  public var clock: Clock
  
  #if os(macOS)
  let window: Window
  #else
  public let window: Window
  #endif
  
  #if os(macOS)
  let view: View
  #else
  let swapChain: SwapChain
  #endif
  
  @MainActor
  public init(descriptor: ApplicationDescriptor) {
    guard let device = descriptor.device,
          let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    self.device = device
    self.display = display
    
    self.clock = Clock(display: display)
    self.window = Window(display: display)
    
    #if os(macOS)
    self.view = View(display: display)
    
    // This assignment is the reason the code must be within a @MainActor
    // scope on macOS.
    window.view = view
    #else
    // Create the swap chain.
    var swapChainDesc = SwapChainDescriptor()
    swapChainDesc.device = device
    swapChainDesc.display = display
    swapChainDesc.window = window
    self.swapChain = SwapChain(descriptor: swapChainDesc)
    #endif
    
    guard Application.singleton == nil else {
      fatalError(
        "Can only create one instance of Application in a program run.")
    }
    Application.singleton = self
  }
  
  #if os(macOS)
  @MainActor
  public func run(
    _ closure: @escaping (MTLTexture) -> Void
  ) {
    guard !didRun else {
      fatalError("Can only run an application one time.")
    }
    didRun = true
    
    var runLoopDesc = RunLoopDescriptor()
    runLoopDesc.closure = closure
    runLoopDesc.display = display
    
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
    
    // This is needed. On some app launches, it makes no difference. On others,
    // the output handler is called dozens of times after the NSApplication
    // stops running.
    runLoop.stop()
  }
  #endif
}
