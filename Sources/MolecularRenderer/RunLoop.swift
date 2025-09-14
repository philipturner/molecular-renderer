#if os(macOS)
import AppKit
#else
import SwiftCOM
import WinSDK
#endif

struct RunLoopDescriptor {
  var closure: (() -> Void)?
  #if os(macOS)
  var display: Display?
  #endif
}

class RunLoop: @unchecked Sendable {
  let closure: () -> Void
  #if os(macOS)
  var displayLink: CVDisplayLink?
  #endif
  
  init(descriptor: RunLoopDescriptor) {
    // Check the closure argument.
    guard let closure = descriptor.closure else {
      fatalError("Descriptor was incomplete.")
    }
    self.closure = closure
    
    #if os(macOS)
    // Check the display argument.
    guard let display = descriptor.display else {
      fatalError("Descriptor was incomplete.")
    }
    
    // Initialize the display link.
    let monitorID = Display.number(
      screen: display.nsScreen)
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkCreateWithCGDisplay(UInt32(monitorID), &displayLink)
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkSetOutputHandler(displayLink!, outputHandler)
    #endif
  }
  
  @MainActor
  func start(window: Window) {
    #if os(macOS)
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkStart(displayLink!)
    
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
    
    // This invocation is the reason the code must be within a @MainActor
    // scope on macOS.
    application.run()
    #else
    ShowWindow(window.hWnd, SW_SHOW)
    
    SetPriorityClass(GetCurrentProcess(), UInt32(HIGH_PRIORITY_CLASS))
    while true {
      var message = MSG()
      let peekMessageOutput = PeekMessageA(
        &message, // lpMsg
        nil, // hWnd
        0, // wMsgFilterMin
        0, // wMsgFilterMax
        UInt32(PM_REMOVE)) // wRemoveMsg
      
      if message.message == WM_QUIT {
        break
      } else if peekMessageOutput {
        TranslateMessage(&message)
        DispatchMessageA(&message)
      }
    }
    #endif
  }
  
  func stop() {
    #if os(macOS)
    // This is needed. On some app launches, it makes no difference. On others,
    // the output handler is called dozens of times after the NSApplication
    // stops running.
    (CVDisplayLinkStruct() as CVDisplayLinkProtocol)
      .CVDisplayLinkStop(displayLink!)
    #endif
  }
}

extension RunLoop {
  #if os(macOS)
  func outputHandler(
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
    
    // Invoke the user-supplied closure.
    self.closure()
    
    // Retrieve the front buffer.
    func retrieveFrontBuffer() -> MTLTexture {
      let bufferIndex = application.renderTarget.currentBufferIndex
      return application.renderTarget.colorTextures[bufferIndex]
    }
    let frontBuffer = retrieveFrontBuffer()
    
    // Retrieve the back buffer.
    func retrieveDrawable() -> CAMetalDrawable {
      let layer = application.view.metalLayer
      let drawable = layer.nextDrawable()
      guard let drawable else {
        fatalError("Drawable timed out after 1 second.")
      }
      return drawable
    }
    let drawable = retrieveDrawable()
    
    // Copy the front buffer to the back buffer and present.
    application.device.commandQueue.withCommandList { commandList in
      commandList.mtlCommandEncoder.endEncoding()
      
      let commandEncoder: MTLBlitCommandEncoder =
      commandList.mtlCommandBuffer.makeBlitCommandEncoder()!
      commandEncoder.copy(
        from: frontBuffer,
        to: drawable.texture)
      commandEncoder.endEncoding()
      
      commandList.mtlCommandBuffer.present(drawable)
      
      commandList.mtlCommandEncoder =
      commandList.mtlCommandBuffer.makeComputeCommandEncoder()!
    }
    
    return kCVReturnSuccess
  }
  #else
  func outputHandler() {
    guard let application = Application.singleton else {
      fatalError("Could not retrieve the application.")
    }
    
    // WARNING: Handle any queued mouse and keyboard events that appeared
    // during this blocking operation.
    func waitOnObject() {
      let result = WaitForSingleObjectEx(
        application.swapChain.waitableObject, // hHandle
        1000, // dwMilliseconds
        true) // bAlertable
      guard result == 0 else {
        fatalError("Failed to wait for object: \(result)")
      }
    }
    
    func updateClock() {
      let frameStatistics =
      try? application.swapChain.d3d12SwapChain
        .GetFrameStatistics()
      application.clock.increment(frameStatistics: frameStatistics)
    }
    
    // Synchronize and update the clock.
    waitOnObject()
    updateClock()
    
    // Invoke the user-supplied closure.
    self.closure()
    
    // Retrieve the front buffer.
    func retrieveFrontBuffer() -> MTLTexture {
      let bufferIndex = application.renderTarget.currentBufferIndex
      return application.renderTarget.colorTextures[bufferIndex]
    }
    let frontBuffer = retrieveFrontBuffer()
    
    // Retrieve the back buffer.
    func retrieveBackBuffer() -> SwiftCOM.ID3D12Resource {
      let bufferIndex = try! application.swapChain.d3d12SwapChain
        .GetCurrentBackBufferIndex()
      return application.swapChain.backBuffers[Int(bufferIndex)]
    }
    let backBuffer = retrieveBackBuffer()
    
    // Present the frame buffer.
    let frameBuffer = application.swapChain.frameBuffer
    let backBuffer = createBackBuffer()
    application.device.commandQueue.withCommandList { commandList in
      // Transitions before the copy command.
      do {
        let barrier1 = Self.transition(
          resource: frameBuffer,
          before: D3D12_RESOURCE_STATE_UNORDERED_ACCESS,
          after: D3D12_RESOURCE_STATE_COPY_SOURCE)
        let barrier2 = Self.transition(
          resource: backBuffer,
          before: D3D12_RESOURCE_STATE_PRESENT,
          after: D3D12_RESOURCE_STATE_COPY_DEST)
        let barriers = [barrier1, barrier2]
        
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
      
      // Copy the frame buffer into the back buffer.
      try! commandList.d3d12CommandList.CopyResource(
        backBuffer, // pDstResource
        frameBuffer) // pSrcResource
      
      // Transition after the copy command.
      do {
        let barrier1 = Self.transition(
          resource: frameBuffer,
          before: D3D12_RESOURCE_STATE_COPY_SOURCE,
          after: D3D12_RESOURCE_STATE_UNORDERED_ACCESS)
        let barrier2 = Self.transition(
          resource: backBuffer,
          before: D3D12_RESOURCE_STATE_COPY_DEST,
          after: D3D12_RESOURCE_STATE_PRESENT)
        let barriers = [barrier1, barrier2]
        
        try! commandList.d3d12CommandList.ResourceBarrier(
          UInt32(barriers.count), barriers)
      }
    }
    
    // Send the render target to the DWM.
    try! application.swapChain.d3d12SwapChain.Present(1, 0)
  }
  #endif
  
  #if os(Windows)
  // Utility function for transitioning resources.
  static func transition(
    resource: SwiftCOM.ID3D12Resource,
    before: D3D12_RESOURCE_STATES,
    after: D3D12_RESOURCE_STATES
  ) -> D3D12_RESOURCE_BARRIER {
    // Specify the type of barrier.
    var barrier = D3D12_RESOURCE_BARRIER()
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION
    barrier.Flags = D3D12_RESOURCE_BARRIER_FLAG_NONE
    
    // Specify the transition's parameters.
    try! resource.perform(
      as: WinSDK.ID3D12Resource.self
    ) { pUnk in
      barrier.Transition.pResource = pUnk
    }
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES
    barrier.Transition.StateBefore = before
    barrier.Transition.StateAfter = after
    
    return barrier
  }
  #endif
}
