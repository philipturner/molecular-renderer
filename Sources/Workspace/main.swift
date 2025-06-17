// Next steps:
// - Merge Window (macOS) with WindowUtilities (Windows).
//
// Current objectives:
// - Rewrite the macOS code to prepare for merging with Windows.
// - Handle the window rect vs. client rect (frame rect vs. contect rect) with
//   less ambiguity.
//   - Start by inspecting the screen coordinates of the frame rect vs.
//     content rect on macOS.
// - Allow the run loop to end without crashing the calling program.
//   - Do not provide a way to end the run loop programmatically. Only add
//     functionality for closing via UI events.

import MolecularRenderer

#if os(macOS)
import Metal

@MainActor
func createApplication() -> Application {
  // Set up the device.
  var deviceDesc = DeviceDescriptor()
  deviceDesc.deviceID = Device.fastestDeviceID
  let device = Device(descriptor: deviceDesc)
  
  // Set up the display.
  var displayDesc = DisplayDescriptor()
  displayDesc.device = device
  displayDesc.frameBufferSize = SIMD2<Int>(1920, 1920)
  displayDesc.monitorID = device.fastestMonitorID
  let display = Display(descriptor: displayDesc)
  
  // Set up the application.
  var applicationDesc = ApplicationDescriptor()
  applicationDesc.device = device
  applicationDesc.display = display
  let application = Application(descriptor: applicationDesc)
  
  return application
}

func createShaderSource() -> String {
  """
  
  #include <metal_stdlib>
  using namespace metal;
  
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
    
    // Write the pixel to the screen.
    frameBuffer.write(color, tid);
  }
  
  """
}

for _ in 0..<2 {
  // Set up the application.
  let application = createApplication()
  
  // Set up the shader.
  var shaderDesc = ShaderDescriptor()
  shaderDesc.device = application.device
  shaderDesc.name = "renderImage"
  shaderDesc.source = createShaderSource()
  shaderDesc.threadsPerGroup = SIMD3(8, 8, 1)
  let shader = Shader(descriptor: shaderDesc)
  
  // Define the state variables.
  var startTime: UInt64?
  
  // Enter the run loop.
  application.run { renderTarget in
    application.device.commandQueue.withCommandList { commandList in
      // Utility function for calculating progress values.
      var times: SIMD3<Float> = .zero
      func setTime(_ time: Double, index: Int) {
        let fractionalTime = time - floor(time)
        times[index] = Float(fractionalTime)
      }
      
      // Write the absolute time.
      if let startTime {
        let currentTime = mach_continuous_time()
        let timeSeconds = Double(currentTime - startTime) / 24_000_000
        setTime(timeSeconds, index: 0)
      } else {
        startTime = mach_continuous_time()
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
  print("return to the program")
}

#endif



#if os(Windows)
import SwiftCOM
import WinSDK

let window = Application.global.window
ShowWindow(window, SW_SHOW)

// Invoke the game loop.
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

// # Initialization procedure and data dependencies
//
// Display
// - source of truth for frame buffer size
// - source of truth for content rect
//   - frame buffer size (Windows)
//   - DPI-scaled window size (macOS)
// - source of truth for work area (DPI-scaled depending on OS)
// - source of truth for frame rate
//
// Clock
// - depends on frame rate
//
// Window
// - depends on content rect
// - depends on 'AdjustWindowRect' for window rect (Windows)
// - depends on 'NSWindow.init' for frame rect (macOS)
// - applicationDidFinishLaunching (macOS) depends on:
//   - expected frame rect
//
// View (macOS)
// - depends on 'Device'
// - depends on frame buffer size
// - depends on content rect
// - assigned as the underlying 'NSView' of the 'NSViewController'
// - setBoundsSize/setFrameSize depends on:
//   - expected content rect
//
// SwapChain (Windows)
// - depends on 'Device'
// - depends on frame buffer size
// - depends on HWND
//
// MessageProcedure (Windows)
// - WM_SIZE response depends on:
//   - HWND to query content rect
//   - expected content rect
