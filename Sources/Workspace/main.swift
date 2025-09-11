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
// - Too early to integrate 'HDL' for generating test structures and debugging
//   the new feature for 2D crystals ('Planar' basis). First, need a
//   functioning renderer that can visualize atoms.
//
// Major restructuring of plans:
// - Focus on core hands-off rendering capability first, to enable testing of
//   external libraries. This will unlock the latest round of planned
//   maintenance on the libraries, especially a new crystal basis in HDL.
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
// - In a similar spirit, the deletion of built-in energy minimization from MM4
//   will unlock more user control.
// - Omitting a 2D basis from the HDL will not provide more user control.
//   Instead, it just makes stuff more tedious. There is a distinct basis with
//   only 2 vectors. And the C-H bonds should not have to shrink away from
//   nominal values as a side effect of originally working in the lonsdaleite
//   basis. Only include the extremely stable graphene and h-BN crystals.
//   Silicene seems to be technical debt, not a stable or useful compound. And
//   transition metal dichalcogenides are out of scope because of the lack of
//   support for the transition metal atoms.
//   - Reconstruction can proceed differently when the underlying basis is
//     2D graphene. The bond topology is respecting pi bonds, not sigma bonds.
//     In addition, the C-H bonds can be made shorter than the sum of atomic
//     radii. Or not; there are valid reasons for either choice.
//   - Wait...the default C-H bond length is already appropriate:
//     - 76 pm + 31 pm = 107 pm
//     - alkanes in MM3: 111.20 pm
//     - alkenes in MM3: 110.10 pm
//     - benzene in MM3: 110.10 pm
//
// Keep these notes around for a little bit, before deleting or archiving them
// in a future commit. It's quite organized to have the plans kept in two
// locations:
// - molecular-renderer/windows-port currently planning renderer + HDL
// - swift-xtb/intercept-linear-algebra currently planning xTB + MM4

import HDL
import MolecularRenderer
#if os(macOS)
import Metal
#else
import SwiftCOM
import WinSDK
#endif

func createShaderSource() -> String {
  func includes() -> String {
    """
    
    struct TimeArguments {
      float time0;
      float time1;
      float time2;
    };
    
    float convertToChannel(
      float hue,
      float saturation,
      float lightness,
      uint n
    ) {
      float k = float(n) + hue / 30;
      k -= 12 * floor(k / 12);
      
      float a = saturation;
      a *= min(lightness, 1 - lightness);
      
      float output = min(k - 3, 9 - k);
      output = max(output, float(-1));
      output = min(output, float(1));
      output = lightness - a * output;
      return output;
    }
    
    """
  }
  
  func shaderBody() -> String {
    """
    
    // Specify the arrangement of the bars.
    float line0 = float(screenHeight) * float(15) / 18;
    float line1 = float(screenHeight) * float(16) / 18;
    float line2 = float(screenHeight) * float(17) / 18;
    
    // Render something based on the pixel's position.
    float4 color;
    if (float(tid.y) < line0) {
      color = float4(0.707, 0.707, 0.00, 1.00);
    } else {
      float progress = float(tid.x) / float(screenWidth);
      if (float(tid.y) < line1) {
        progress += timeArgs.time0;
      } else if (float(tid.y) < line2) {
        progress += timeArgs.time1;
      } else {
        progress += timeArgs.time2;
      }
      
      float hue = float(progress) * 360;
      float saturation = 1.0;
      float lightness = 0.5;
      
      float red = convertToChannel(hue, saturation, lightness, 0);
      float green = convertToChannel(hue, saturation, lightness, 8);
      float blue = convertToChannel(hue, saturation, lightness, 4);
      color = float4(red, green, blue, 1.00);
    }
    
    """
  }
  
  #if os(macOS)
  return """
  
  #include <metal_stdlib>
  using namespace metal;
  
  \(includes())
  
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
    
    \(shaderBody())
    
    // Write the pixel to the screen.
    frameBuffer.write(color, tid);
  }
  
  """
  #else
  func rootSignature() -> String {
    """
    "RootConstants(num32BitConstants = 3, b0),"
    "DescriptorTable(UAV(u0, numDescriptors = 1)),"
    """
  }
  
  return """
  
  \(includes())
  
  ConstantBuffer<TimeArguments> timeArgs : register(b0);
  RWTexture2D<float4> frameBuffer : register(u0);
  
  [numthreads(8, 8, 1)]
  [RootSignature(\(rootSignature()))]
  void renderImage(
    uint2 tid : SV_DispatchThreadID
  ) {
    // Query the screen's dimensions.
    uint screenWidth;
    uint screenHeight;
    frameBuffer.GetDimensions(screenWidth, screenHeight);
    if ((tid.x >= screenWidth) ||
        (tid.y >= screenHeight)) {
      return;
    }
    
    \(shaderBody())
    
    // Write the pixel to the screen.
    frameBuffer[tid] = color;
  }
  
  """
  
  #endif
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
      
      #if os(macOS)
      commandList.mtlCommandEncoder
        .setTexture(renderTarget, index: 1)
      #else
      try! commandList.d3d12CommandList
        .SetDescriptorHeaps([renderTarget])
      let gpuDescriptorHandle = try! renderTarget
        .GetGPUDescriptorHandleForHeapStart()
      try! commandList.d3d12CommandList
        .SetComputeRootDescriptorTable(1, gpuDescriptorHandle)
      #endif
      
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
