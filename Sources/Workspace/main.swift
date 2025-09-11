// Next steps:
// - Allow the window to be closed with "Ctrl + W" on Windows.
// - Track keyboard and mouse events, establishing a prototype of the
//   'UserInterface' utility.
//   - Decide on how to hide the cursor from the user. Not a trivial decision.
//     - Previously, hid when the user entered the window. Because of stability
//       issues, the user must press 'Esc' once before the first mouse hide.
//     - Afterward, 'Esc' is used to toggle mouse visibility.
//     - The mouse is only tracked and connected to camera movements when the
//       cursor is hidden.
//     - Presence of mouse hiding is clearly indicated by the crosshair. We'll
//       need to delete the crosshair to remove technical debt.
//   - Don't elaborate on mouse sensitivity, because we're far from the point
//     where we can place the user into a scene. Instead, just track the
//     accumulated mouse X/Y screen position from the OS. Normalize this
//     position to fractions of the window size, or whatever basis was needed
//     for the old renderer to function.
//   - The mouse should only be hidden if specifically the script denotes it.
//     In hands-off rendering, the window should not interact with UI events.
//     - Near-term, this can be a simple boolean in the Application class. But
//       long-term, I haven't settled on an optimal API.
//     - Defer this decision until I have a functioning 'UserInterface' API
//       that can be selectively activated under user control.
//
// Major restructuring of plans:
// - Structure the UI capability to give the user complete control over how
//   events are handled.
//   - If they want a pure offline movie, they don't trigger any interactions
//     with the mouse.
//   - They should be able to render custom overlays via GPU shaders. In fact,
//     the core atom renderer is just a very flexible framework for setting up
//     shaders and integrating them with TAAU.
//   - Mouse movements must be exposed in a way that's consistent across
//     devices and display resolutions.
//     - Normalizing for window size is best left to the user.
//     - Mouse movements should be presented in physical screen coordinates.
//   - UI events should not be provided when the window is out of focus.
//   - Cursor hiding is an event the backend performs when an API function is
//     invoked. The user decides what locks/unlocks it.
//   - 'UserInterface' is not baked into the codebase. Instead, it's provided
//     in reference code in an external library, just like energy minimization,
//     caching on disk, and encoding raw image buffers to serialized video
//     formats.
//
// Two conclusions from the above plans:
// - Establish the low-level UI event handling or forwarding
// - Need a minimum, bare-bones programmatic renderer like the earliest
//   iteration of molecular-renderer. Doesn't need to be optimized or visually
//   pleasing, just good enough to see movements in 3D.
// - Host the UserInterface utility in a GitHub gist or other appropriate
//   location, intentionally outside the library code. This choice is justified
//   by the need to decouple unrelated software modules.
//
// Plan:
// - Get a minimum programmatic, hands-off renderer on macOS.
// - If needed, migrate some code from 'Workspace' to the main library.
// - Switch over to Windows, repair the 'run' script, and port the code
//   developed on macOS.

import HDL
import MolecularRenderer
#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

func createShaderSource() -> String {
  return """
  
  #include <metal_stdlib>
  using namespace metal;
  
  struct TimeArguments {
    float time0;
    float time1;
    float time2;
  };
  
  kernel void renderImage(
    constant TimeArguments &timeArgs [[buffer(0)]],
    texture2d<float, access::write> frameBuffer [[texture(1)]],
    uint2 tid [[thread_position_in_grid]]
  ) {
    // Query the screen's dimensions.
    uint screenWidth = frameBuffer.get_width();
    uint screenHeight = frameBuffer.get_height();
    if ((tid.x >= screenWidth) ||
        (tid.y >= screenHeight)) {
      return;
    }
    
    // Render something based on the pixel's position.
    float4 color = float4(0.707, 0.707, 0.00, 1.00);
    
    // Write the pixel to the screen.
    frameBuffer.write(color, tid);
  }
  
  """
}

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  #if os(macOS)
  displayDesc.frameBufferSize = SIMD2<Int>(1920, 1920)
  #else
  displayDesc.frameBufferSize = SIMD2<Int>(1440, 1440)
  #endif
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  let application = Application(descriptor: applicationDesc)
  
  return application
}

// Set up the application.
let application = createApplication()

// Set up the shader.
var shaderDesc = ShaderDescriptor()
shaderDesc.device = application.device
shaderDesc.name = "renderImage"
shaderDesc.source = createShaderSource()
#if os(macOS)
shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
#endif
let shader = Shader(descriptor: shaderDesc)



func queryTickCount() -> UInt64 {
  #if os(macOS)
  return mach_continuous_time()
  #else
  var largeInteger = LARGE_INTEGER()
  QueryPerformanceCounter(&largeInteger)
  return UInt64(largeInteger.QuadPart)
  #endif
}

func ticksPerSecond() -> Int {
  #if os(macOS)
  return 24_000_000
  #else
  return 10_000_000
  #endif
}

// Define the state variables.
var startTicks: UInt64?

// Enter the run loop.
application.run { renderTarget in
  application.device.commandQueue.withCommandList { commandList in
    // Utility function for calculating progress values.
    var times: SIMD3<Float> = .zero
    func setTime(_ time: Double, index: Int) {
      let fractionalTime = time - time.rounded(.down)
      times[index] = Float(fractionalTime)
    }
    
    // Write the absolute time.
    if let startTicks {
      let elapsedTicks = queryTickCount() - startTicks
      let timeSeconds = Double(elapsedTicks) / Double(ticksPerSecond())
      setTime(timeSeconds, index: 0)
    } else {
      startTicks = queryTickCount()
      setTime(Double.zero, index: 0)
    }
    
    // Write the time according to the counter.
    do {
      let clock = application.clock
      let timeInFrames = clock.frames
      let framesPerSecond = application.display.frameRate
      let timeInSeconds = Double(timeInFrames) / Double(framesPerSecond)
      setTime(timeInSeconds, index: 1)
      setTime(Double.zero, index: 2)
    }
    
    // Fill the arguments data structure.
    struct TimeArguments {
      var time0: Float = .zero
      var time1: Float = .zero
      var time2: Float = .zero
    }
    var timeArgs = TimeArguments()
    timeArgs.time0 = times[0]
    timeArgs.time1 = times[1]
    timeArgs.time2 = times[2]
    
    // Encode the compute command.
    commandList.withPipelineState(shader) {
      commandList.set32BitConstants(timeArgs, index: 0)
      
      commandList.mtlCommandEncoder
        .setTexture(renderTarget, index: 1)
      
      let frameBufferSize = application.display.frameBufferSize
      let groupSize = SIMD2<Int>(8, 8)
      
      var groupCount = frameBufferSize
      groupCount &+= groupSize &- 1
      groupCount /= groupSize
      
      let groupCount32 = SIMD3<UInt32>(
        UInt32(groupCount[0]),
        UInt32(groupCount[1]),
        UInt32(1))
      commandList.dispatch(groups: groupCount32)
    }
  }
}
